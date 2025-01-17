unit Web.Module;

interface

uses
  System.SysUtils, System.Classes, Web.HTTPApp, Datasnap.DSHTTPCommon,
  Datasnap.DSHTTPWebBroker, Datasnap.DSServer,
  Web.WebFileDispatcher, Web.HTTPProd,
  DataSnap.DSAuth,
  Datasnap.DSProxyJavaScript, IPPeerServer, Datasnap.DSMetadata,
  Datasnap.DSServerMetadata, Datasnap.DSClientMetadata, Datasnap.DSCommonServer,
  Datasnap.DSHTTP, System.JSON, REST.Json, Server.Controller,
  Server.Model, Server.Container;

type
  TWebModule1 = class(TWebModule)
    DSHTTPWebDispatcher1: TDSHTTPWebDispatcher;
    WebFileDispatcher1: TWebFileDispatcher;
    DSProxyGenerator1: TDSProxyGenerator;
    DSServerMetaDataProvider1: TDSServerMetaDataProvider;
    procedure WebModule1DefaultHandlerAction(Sender: TObject;
      Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
    procedure WebFileDispatcher1BeforeDispatch(Sender: TObject;
      const AFileName: string; Request: TWebRequest; Response: TWebResponse;
      var Handled: Boolean);
    procedure WebModuleCreate(Sender: TObject);
    procedure WebModuleBeforeDispatch(Sender: TObject; Request: TWebRequest;
      Response: TWebResponse; var Handled: Boolean);
  private
    function GetIDsFromURL(const URL: string; out idServidor, idVideo: TGUID): Boolean;
    procedure PostVideoToServer;
    procedure PostCreateServer;
    procedure PutUpdateServer;
    procedure GetDownloadBinaryVideo;
    procedure DeleteServer;
    procedure DeleteVideo;
    procedure DeleteVideoRecyclerProcess;
    procedure GetServerAvailable;
    procedure GetServer;
    procedure GetVideo;
    procedure GetAllServers;
    procedure GetAllVideos;
    procedure GetRecyclerStatus;

    var
      RecyclerIsRunning: Boolean;
  public
    { Public declarations }
  end;

var
  WebModuleClass: TComponentClass = TWebModule1;

implementation


{$R *.dfm}

uses Web.WebReq, System.StrUtils, System.DateUtils, Videos.Model;

procedure TWebModule1.WebModule1DefaultHandlerAction(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
begin
  Response.Content :=
    'Nenhuma a��o foi encontrada para esse caminho! Verfique se o caminho confere com os URLs pr�-estabelecidos: ' + #13+
    ' /api/server' + #13+
    ' /api/servers/{idServidor}' + #13+
    ' /api/servers/available/{idServidor}' + #13+
    ' /api/servers' + #13+
    ' /api/servers/{idServidor}/videos' + #13+
    ' /api/servers/{idServidor}/videos/{idVideo}' + #13+
    ' /api/servers/{idServidor}/videos/{idVideo}/binary' + #13+
    ' /api/servers/{idServidor}/vid' + #13+
    ' /api/recycler/process/{days}' + #13+
    ' /api/recycler/status' + #13;
end;

procedure TWebModule1.WebModuleBeforeDispatch(Sender: TObject;
  Request: TWebRequest; Response: TWebResponse; var Handled: Boolean);
var
  JSONObj: TJSONObject;
begin
  try
    if Request.Method = 'GET' then
    begin
      if ContainsText(Request.PathInfo, '/api/servers/available/') then
        GetServerAvailable;

      if ContainsText(Request.PathInfo, '/api/servers/') and not (ContainsText(Request.PathInfo, '/available/')  or ContainsText(Request.PathInfo,  '/videos/') or ContainsText(Request.PathInfo,  '/videos')) then
        GetServer;

      if Request.PathInfo = '/api/servers' then
        GetAllServers;

      if ContainsText(Request.PathInfo, '/api/servers/') and ContainsText(Request.PathInfo, '/videos/') then
          GetVideo;

      if ContainsText(Request.PathInfo, '/api/servers/') and ContainsText(Request.PathInfo, '/videos') then
          GetAllVideos;

      if Request.PathInfo = '/api/recycler/status' then
          GetRecyclerStatus;

      if ContainsText(Request.PathInfo, '/api/servers/') and ContainsText(Request.PathInfo, '/videos/') and ContainsText(Request.PathInfo, '/binary') then
        GetDownloadBinaryVideo;
    end
    else if Request.Method = 'POST' then
    begin
      if ContainsText(Request.PathInfo, '/api/servers/') and ContainsText(Request.PathInfo, '/videos') then
        PostVideoToServer;

      if Request.PathInfo = '/api/server' then
        PostCreateServer;
    end
    else if Request.Method = 'PUT' then
    begin
      if StartsText('/api/servers/', Request.PathInfo) then
        PutUpdateServer;
    end
    else if Request.Method = 'DELETE' then
    begin
      if ContainsText(Request.PathInfo, '/api/servers/') and not ContainsText(Request.PathInfo, '/videos/') then
        DeleteServer;

      if ContainsText(Request.PathInfo, '/api/servers/') and ContainsText(Request.PathInfo, '/videos/') then
        DeleteVideo;

      if ContainsText(Request.PathInfo, '/api/recycler/process/') then
        DeleteVideoRecyclerProcess;
    end;
  finally
    Handled := True;
    JSONObj.Free;
  end;
end;

procedure TWebModule1.DeleteServer;
var
  idServidor: TGUID;
begin

  try
    idServidor := StringToGUID(Copy(Request.PathInfo, Length('/api/servers/') + 1));
  except
  on E: Exception do
    begin
      Response.StatusCode := 400; // Bad Request
      Response.Content := '{"error":"Invalid server ID"}';

      Exit;
    end;
  end;

  if TServerController.DeleteServer(idServidor) then
  begin
    Response.StatusCode := 204; // No Content (Sucess, no response needed)
  end
  else
  begin
    Response.StatusCode := 404; // Not Found
    Response.Content := '{"error":"Server not found"}';
  end;
end;

procedure TWebModule1.DeleteVideo;
var
  idServidor, idVideo: TGUID;
  URL: string;
begin
  URL := Request.PathInfo;

  if GetIDsFromURL(URL, idServidor, idVideo) then
    if TServerController.DeleteVideo(idServidor, idVideo) then
    begin
      Response.StatusCode := 204; // No Content (Sucess, no response needed)
    end
    else
    begin
      Response.StatusCode := 404; // Not Found
      Response.Content := '{"error":"Video not found"}';
    end;
end;

procedure TWebModule1.DeleteVideoRecyclerProcess;
var
  daysStr: string;
  days: Integer;
begin
  daysStr := Copy(Request.PathInfo, Length('/api/recycler/process/') + 1);
  days := StrToInt(daysStr);

  RecyclerIsRunning := True;

  if TServerController.DeleteVideoRecyclerProcess(days) then
  begin
    RecyclerIsRunning := False;
    Response.StatusCode := 204;
  end
  else
  begin
    RecyclerIsRunning := False;
    Response.StatusCode := 400; // Bad Request
    Response.Content := TJSONObject.Create.AddPair('error', 'Invalid days parameter').ToString;
  end;
end;

procedure TWebModule1.GetAllServers;
var
  serverListJSON: TJSONArray;
begin
  serverListJSON := TServerController.GetAllServers;
  try
    Response.ContentType := 'application/json';
    Response.Content := serverListJSON.ToString;
  finally
    serverListJSON.Free;
  end;
end;

procedure TWebModule1.GetAllVideos;
var
  videoListJSON: TJSONArray;
begin
  VideoListJSON := TServerController.GetAllVideos;
  try
    Response.ContentType := 'application/json';
    Response.Content := videoListJSON.ToString;
  finally
    videoListJSON.Free;
  end;
end;


function TWebModule1.GetIDsFromURL(const URL: string; out idServidor, idVideo: TGUID): Boolean;
var
  idServidorStr, idVideoStr: string;
  idServidorPos, idVideoPos, BinaryPos: Integer;
begin
  Result := False;

  idServidorPos := Pos('/api/servers/', URL);
  if idServidorPos = 0 then Exit;

  idVideoPos := Pos('/videos/', URL);
  if idVideoPos = 0 then Exit;

  idServidorStr := Copy(URL, idServidorPos + Length('/api/servers/'),
    idVideoPos - (idServidorPos + Length('/api/servers/')));

  BinaryPos := Pos('/binary', URL);
  if BinaryPos > 0 then
    idVideoStr := Copy(URL, idVideoPos + Length('/videos/'), BinaryPos - (idVideoPos + Length('/videos/')))
  else
    idVideoStr := Copy(URL, idVideoPos + Length('/videos/'), Length(URL) - (idVideoPos + Length('/videos/')) + 1);

  try
    idServidor := StringToGUID(idServidorStr);
    idVideo := StringToGUID(idVideoStr);
    Result := True;
  except
    Result := False;
  end;
end;

procedure TWebModule1.GetRecyclerStatus;
begin
  if RecyclerIsRunning then
    Response.Content := TJSONObject.Create.AddPair('status', 'is running').ToString
  else
    Response.Content := TJSONObject.Create.AddPair('status', 'not running').ToString;
  Response.StatusCode := 200;
end;

procedure TWebModule1.GetServer;
var
  idServidor: TGUID;
  serverJSON: TJSONObject;
begin

  try
    idServidor := StringToGUID(Copy(Request.PathInfo, Length('/api/servers/') + 1));
  except
    on E: Exception do
    begin
      Response.StatusCode := 400; // Bad Request
      Response.Content := '{"error":"Invalid server ID"}';
      Exit;
    end;
  end;

  serverJSON := TServerController.GetServer(idServidor);
  try
    if Assigned(serverJSON) then
    begin
      Response.ContentType := 'application/json';
      Response.Content := serverJSON.ToString;
    end
    else
    begin
      Response.StatusCode := 404; // Not Found
      Response.Content := '{"error":"Server not found"}';
    end;
    finally
      serverJSON.Free;
    end;
end;

procedure TWebModule1.GetServerAvailable;
var
  idServidor: TGUID;
  serverAvailable: Boolean;
  Server : TServer;
  JSONObjResponse : TJSONObject;
begin

  try
    idServidor := StringToGUID(Copy(Request.PathInfo, Length('/api/servers/available/') + 1, MaxInt));
  except
    on E: Exception do
    begin
      Response.StatusCode := 400; // Bad Request
      Response.Content := '{"error":"Invalid server ID"}';
      Exit;
    end;
  end;

  Server := TServerController.FindServerByID(idServidor);
  if not Assigned(Server) then
  begin
    Response.StatusCode := 404; // Not Found
    Response.Content := '{"error":"Server not found"}';
    Exit;
  end;

  ServerAvailable := TServerController.CheckServerAvailability(idServidor);

  JSONObjResponse := TJSONObject.Create;
  try
    JSONObjResponse.AddPair('ip_address', Server.IpAddress);
    JSONObjResponse.AddPair('ip_port', Server.IpPort.ToString);
    JSONObjResponse.AddPair('available', TJSONBool.Create(serverAvailable));

    Response.ContentType := 'application/json';
    Response.Content := JSONObjResponse.ToString;
  finally
    JSONObjResponse.Free;
  end;
end;

procedure TWebModule1.GetVideo;
var
  idServidor, idVideo: TGUID;
  videoJSON: TJSONObject;
  URL: String;
begin
  URL := Request.PathInfo;

  if GetIDsFromURL(URL, idServidor, idVideo) then
    videoJSON := TServerController.GetVideo(idServidor, idVideo);
    try
      if Assigned(videoJSON) then
      begin
        Response.ContentType := 'application/json';
        Response.Content := videoJSON.ToString;
      end
      else
      begin
        Response.StatusCode := 404; // Not Found
        Response.Content := '{"error":"Server not found"}';
      end;
      finally
        videoJSON.Free;
      end;
end;

procedure TWebModule1.PostCreateServer;
var
  nomeServidor, ipAddress: string;
  ipPort: Integer;
  serverJSON: TJSONObject;
  JSONObj: TJSONObject;
begin
  JSONObj := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;

  if not Assigned(JSONOBj) then
  begin
    Response.StatusCode := 400;
    Response.Content := '{"error":"Invalid JSON"}';
    exit;
  end;

  nomeServidor := JSONObj.GetValue<string>('name');
  ipAddress := JSONObj.GetValue<string>('ip_address');
  ipPort := JSONObj.GetValue<Integer>('ip_port');

  serverJSON := TServerController.CreateServer(nomeServidor, ipAddress, ipPort);
  
  Response.ContentType := 'application/json';
  Response.Content := serverJSON.ToString;

  Response.StatusCode := 201;
end;

procedure TWebModule1.PostVideoToServer;
var
  idServidor: TGUID;
  Server: TServer;
  descricao, videoBase64: String;
  dataInclusao: TDate;
  videoJSON: TJSONObject;
  JSONObj: TJSONObject;
begin
  JSONObj := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;

  if not Assigned(JSONOBj) then
  begin
    Response.StatusCode := 400;
    Response.Content := '{"error":"Invalid JSON"}';
    exit;
  end;

  idServidor := StringToGUID(JSONObj.GetValue<string>('server_id'));
  descricao := JSONObj.GetValue<string>('description');
  videoBase64 := JSONObj.GetValue<string>('content');
  dataInclusao := ISO8601ToDate(JSONObj.GetValue<string>('inclusion_date'));

  Server := TServerController.FindServerByID(idServidor);
  if not Assigned(Server) then
    raise Exception.Create('Server not found');

  videoJSON := TServerController.CreateVideo(Server, descricao, videoBase64, dataInclusao);

  Response.ContentType := 'application/json';
  Response.Content := videoJSON.ToString;

  Response.StatusCode := 201;
end;

procedure TWebModule1.GetDownloadBinaryVideo;
var
  idServidor, idVideo: TGUID;
  Server: TServer;
  Video: TVideo;
  URL: String;
  videoStream: TStream;
begin
  URL := Request.PathInfo;

  if GetIDsFromURL(URL, idServidor, idVideo) then
  begin
    Server := TServerController.FindServerByID(idServidor);
    Video := TServerController.FindVideoByIDs(idServidor, idVideo);

    if Assigned(Video) and Assigned(Server) then
    begin
      videoStream := TServerController.DownloadBinaryVideo(Video);
      try
        if VideoStream.Size > 0 then
        begin
          Response.ContentType := 'application/octet-stream';
          Response.SetCustomHeader('Content-Disposition', 'attachment; filename="video.dat"');
          Response.StatusCode := 200;
          Response.ContentStream := VideoStream;
        end
        else
        begin
          VideoStream.Free;
          Response.StatusCode := 500; // Internal Server Error
          Response.Content := '{"error":"Internal Server Error: Binary stream is empty"}';
        end;
      except
        on E: Exception do
        begin
          VideoStream.Free;
          Response.StatusCode := 500; // Internal Server Error
          Response.Content := Format('{"error":"%s"}', [E.Message]);
        end;
      end;
    end
    else
    begin
      Response.StatusCode := 404; // Not Found
      Response.Content := '{"error":"Video or Server not found"}';
    end;
  end
  else
  begin
    Response.StatusCode := 400; // Bad Request
    Response.Content := '{"error":"Invalid URL format"}';
  end;
end;

procedure TWebModule1.PutUpdateServer;
var
  nomeServidor, ipAddress: string;
  ipPort: Integer;
  idServidor: TGUID;
  serverJSON: TJSONObject;
  JSONObj: TJSONObject;
begin
  JSONObj := TJSONObject.ParseJSONValue(Request.Content) as TJSONObject;

  if not Assigned(JSONOBj) then
  begin
    Response.StatusCode := 400;
    Response.Content := '{"error":"Invalid JSON"}';
    exit;
  end;


  try
   idServidor := StringToGUID(Copy(Request.PathInfo, Length('/api/servers/') + 1));
  except
  on E: Exception do
    begin
      Response.StatusCode := 400; // Bad Request
      Response.Content := '{"error":"Invalid server ID"}';

      Exit;
    end;
  end;

  nomeServidor := JSONObj.GetValue<string>('name');
  ipAddress := JSONObj.GetValue<string>('ip_address');
  ipPort := JSONObj.GetValue<Integer>('ip_port');

  serverJSON := TServerController.UpdateServer(idServidor, nomeServidor, ipAddress, ipPort);

  if Assigned(serverJSON) then
  begin
    Response.ContentType := 'application/json';
    Response.Content := serverJSON.ToString;

    Response.StatusCode := 200;
  end;
end;

procedure TWebModule1.WebFileDispatcher1BeforeDispatch(Sender: TObject;
  const AFileName: string; Request: TWebRequest; Response: TWebResponse;
  var Handled: Boolean);
var
  D1, D2: TDateTime;
begin
  Handled := False;
  if SameFileName(ExtractFileName(AFileName), 'serverfunctions.js') then
    if not FileExists(AFileName) or (FileAge(AFileName, D1) and FileAge(WebApplicationFileName, D2) and (D1 < D2)) then
    begin
      DSProxyGenerator1.TargetDirectory := ExtractFilePath(AFileName);
      DSProxyGenerator1.TargetUnitName := ExtractFileName(AFileName);
      DSProxyGenerator1.Write;
    end;
end;

procedure TWebModule1.WebModuleCreate(Sender: TObject);
begin
  DSServerMetaDataProvider1.Server := DSServer;
  DSHTTPWebDispatcher1.Server := DSServer;
  if DSServer.Started then
  begin
    DSHTTPWebDispatcher1.DbxContext := DSServer.DbxContext;
    DSHTTPWebDispatcher1.Start;
  end;
end;

initialization
finalization
  Web.WebReq.FreeWebModules;

end.

