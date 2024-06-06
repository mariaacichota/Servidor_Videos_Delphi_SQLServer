unit Server.Controller;

interface

uses System.Classes, System.StrUtils, Vcl.Dialogs, Datasnap.DSServer, Datasnap.DSAuth,
     IPPeerServer, Datasnap.DSCommonServer, IdTCPClient, REST.Json, System.JSON,
     Server.Model, Videos.Model, System.NetEncoding, Vcl.StdCtrls, System.Net.HttpClient,
     Data.DB, Data.Win.ADODB, Winapi.ActiveX, System.DateUtils;

type
{$METHODINFO ON}
  TServerController = class(TComponent)

  private
    class var FConnection: TADOConnection;
    class procedure InitializeConnection;

  public
    class function CreateServer(AName, AIPAddress: string; AIPPort: Integer): TJSONObject;
    class function CreateVideo(Server: TServer; Description, Content: String; InclusionDate: TDateTime): TJSONObject;
    class function UpdateServer(AID: TGUID; AName, AIPAddress: string; AIPPort: Integer): TJSONObject;
    class function DeleteServer(AID: TGUID): Boolean;
    class function DeleteVideo(ServerID, VideoID: TGUID): Boolean;
    class function GetServer(AID: TGUID): TJSONObject;
    class function GetVideo(ServerID, VideoID: TGUID): TJSONObject;
    class function CheckServerAvailability(AID: TGUID): Boolean;
    class function GetAllServers: TJSONArray;
    class function GetAllVideos: TJSONArray;
    class function DownloadBinaryVideo(Video: TVideo): TStream;
    class function DeleteVideoRecyclerProcess(Days: Integer): Boolean;

    class function FindServerByID(AID: TGUID): TServer;
    class function FindVideoByIDs(ServerID, VideoID: TGUID): TVideo;
  end;

{$METHODINFO OFF}

implementation

uses
  System.Generics.Collections, System.SysUtils;

{ TServerController }

class function TServerController.CheckServerAvailability(AID: TGUID): Boolean;
var
  Servidor: TServer;
  TCPClient: TIdTCPClient;
begin
  Servidor := FindServerByID(AID);
  if Assigned(Servidor) then
  begin
    TCPClient := TIdTCPClient.Create(nil);
    try
      TCPClient.Host := Servidor.IPAddress;
      TCPClient.Port := Servidor.IPPort;
      try
        TCPClient.ConnectTimeout := 5000; // Timeout de 5 segundos
        TCPClient.Connect;
        Result := TCPClient.Connected;
      except
        Result := False;
      end;
    finally
      TCPClient.Free;
    end;
  end
  else
  begin
    Result := False;
  end;
end;

class function TServerController.CreateServer(AName, AIPAddress: string;
  AIPPort: Integer): TJSONObject;
var
  Query: TADOQuery;
  ServerID: TGUID;
begin
  try
    InitializeConnection;
    ServerID := TGUID.NewGuid;
    Query := TADOQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'INSERT INTO SERVIDOR (Id, NOME, IP_ADDRESS, IP_PORT) VALUES (:Id, :Nome, :IPAddress, :IPPort)';
      Query.Parameters.ParamByName('Id').Value := ServerID.ToString;
      Query.Parameters.ParamByName('Nome').Value := AName;
      Query.Parameters.ParamByName('IPAddress').Value := AIPAddress;
      Query.Parameters.ParamByName('IPPort').Value := AIPPort;
      Query.ExecSQL;

      Result := TJSONObject.Create;
      Result.AddPair('Id', TJSONString.Create(GuidToString(ServerID)));
      Result.AddPair('Nome', TJSONString.Create(AName));
      Result.AddPair('IPAddress', TJSONString.Create(AIPAddress));
      Result.AddPair('IPPort', TJSONNumber.Create(AIPPort));
    except
      Result.Free;
      raise;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end;

class function TServerController.CreateVideo(Server: TServer; Description,
  Content: String; InclusionDate: TDateTime): TJSONObject;
var
  Query: TADOQuery;
  VideoID: TGUID;
  VideoContent: TBytes;
  InclusionDateStr: string;
begin
  try
    InitializeConnection;
    VideoID := TGUID.NewGuid;
    VideoContent := TNetEncoding.Base64.DecodeStringToBytes(Content);
    InclusionDateStr := FormatDateTime('yyyy-mm-dd hh:nn:ss', InclusionDate);

    Query := TADOQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'INSERT INTO VIDEOS (Id, DESCRICAO, CONTEUDO, SERVIDOR_ID, DATA_INCLUSAO) VALUES (:Id, :Descricao, :Conteudo, :ServdorId, :DataInclusao)';
      Query.Parameters.ParamByName('Id').Value := VideoID.ToString;
      Query.Parameters.ParamByName('Descricao').Value := Description;
      Query.Parameters.ParamByName('Conteudo').Value := VideoContent;
      Query.Parameters.ParamByName('ServdorId').Value := Server.ID.ToString;
      Query.Parameters.ParamByName('DataInclusao').Value := InclusionDateStr;
      Query.ExecSQL;

      Result := TJSONObject.Create;
      Result.AddPair('Id', TJSONString.Create(GuidToString(VideoID)));
      Result.AddPair('Descricao', TJSONString.Create(Description));
      Result.AddPair('Conteudo', TJSONString.Create(Content));
      Result.AddPair('ServdorId', TJSONString.Create(Server.ID.ToString));
      Result.AddPair('DataInclusao', TJSONString.Create(InclusionDateStr));
    except
      Result.Free;
      raise;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end;

class function TServerController.DeleteServer(AID: TGUID): Boolean;
var
  Query: TADOQuery;
  RowsAffected: Integer;
begin
  InitializeConnection;

  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM SERVIDOR WHERE Id = :ID';
    Query.Parameters.ParamByName('ID').Value := AID.ToString;
    RowsAffected := Query.ExecSQL;

    Result := RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

class function TServerController.DeleteVideo(ServerID, VideoID: TGUID): Boolean;
var
  Query: TADOQuery;
  RowsAffected: Integer;
begin
  InitializeConnection;

  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM VIDEOS WHERE Id = :ID AND SERVIDOR_ID = :ServerId';
    Query.Parameters.ParamByName('ID').Value := VideoID.ToString;
    Query.Parameters.ParamByName('ServerId').Value := ServerID.ToString;
    RowsAffected := Query.ExecSQL;

    Result := RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

class function TServerController.DeleteVideoRecyclerProcess(
  Days: Integer): Boolean;
var
  Query: TADOQuery;
  RowsAffected: Integer;
  DateLimit: TDateTime;
begin
  InitializeConnection;

  DateLimit := IncDay(Now, -Days);

  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM VIDEOS WHERE DATA_INCLUSAO < :DateLimit';
    Query.Parameters.ParamByName('DateLimit').Value := DateLimit;
    RowsAffected := Query.ExecSQL;

    Result := RowsAffected > 0;
  finally
    Query.Free;
  end;
end;

class function TServerController.DownloadBinaryVideo(Video: TVideo): TStream;
begin
  Result := TMemoryStream.Create;
  try
    if Length(Video.Content) > 0 then
    begin
      Result.WriteBuffer(Video.Content[0], Length(Video.Content));
      Result.Position := 0;
    end
    else
    begin
      raise Exception.Create('Video content is empty');
    end;
  except
    on E: Exception do
    begin
      Result.Free;
      raise Exception.Create('Error while creating video binary stream: ' + E.Message);
    end;
  end;
end;

class function TServerController.FindServerByID(AID: TGUID): TServer;
var
  Query: TADOQuery;
begin
  InitializeConnection;

  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Id, NOME, IP_ADDRESS, IP_PORT FROM SERVIDOR WHERE ID = :ID';
    Query.Parameters.ParamByName('ID').Value := AID.ToString;
    Query.Open;

    if not Query.Eof then
    begin
      Result := TServer.Create;
      Result.ID := StringToGUID(Query.FieldByName('Id').AsString);
      Result.Name := Query.FieldByName('NOME').AsString;
      Result.IPAddress := Query.FieldByName('IP_ADDRESS').AsString;
      Result.IPPort := Query.FieldByName('IP_PORT').AsInteger;
    end
    else
      Result := nil;
  finally
    Query.Free;
  end;
end;

class function TServerController.FindVideoByIDs(ServerID, VideoID: TGUID): TVideo;
var
  Query: TADOQuery;
begin
  InitializeConnection;

  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Id, DESCRICAO, CONTEUDO, SERVIDOR_ID, DATA_INCLUSAO FROM VIDEOS WHERE Id = :ID AND SERVIDOR_ID = :ServerId';
    Query.Parameters.ParamByName('ID').Value := VideoID.ToString;
    Query.Parameters.ParamByName('ServerId').Value := ServerID.ToString;
    Query.Open;

    if not Query.Eof then
    begin
      Result := TVideo.Create;
      Result.ID := StringToGUID(Query.FieldByName('Id').AsString);
      Result.Description := Query.FieldByName('DESCRICAO').AsString;
      Result.Content := TNetEncoding.Base64.DecodeStringToBytes(Query.FieldByName('CONTEUDO').AsString);
      Result.DataInclusao := Query.FieldByName('DATA_INCLUSAO').AsString;
    end
    else
      Result := nil;
  finally
    Query.Free;
  end;
end;

class function TServerController.GetAllServers: TJSONArray;
var
  Servidor: TServer;
  JSONArray: TJSONArray;
  Query: TADOQuery;
begin
  InitializeConnection;

  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Id, NOME, IP_ADDRESS, IP_PORT FROM SERVIDOR';
    Query.Open;

    JSONArray := TJSONArray.Create;
    try
      while not Query.Eof do
      begin
        Servidor := TServer.Create;
        Servidor.ID := StringToGUID(Query.FieldByName('Id').AsString);
        Servidor.Name := Query.FieldByName('NOME').AsString;
        Servidor.IPAddress := Query.FieldByName('IP_ADDRESS').AsString;
        Servidor.IPAddress := Query.FieldByName('IP_PORT').AsString;

        JSONArray.AddElement(TJson.ObjectToJsonObject(Servidor));
        Query.Next;
      end;

      Result := JSONArray;
    except
      JSONArray.Free;
      raise;
    end;
  finally
    Query.Free;
  end;
end;

class function TServerController.GetAllVideos: TJSONArray;
var
  Video: TVideo;
  JSONArray: TJSONArray;
  Query: TADOQuery;
begin
  InitializeConnection;

  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT Id, DESCRICAO, CONTEUDO, SERVIDOR_ID, DATA_INCLUSAO FROM VIDEOS';
    Query.Open;

    JSONArray := TJSONArray.Create;
    try
      while not Query.Eof do
      begin
        Video := TVideo.Create;
        Video.ID := StringToGUID(Query.FieldByName('Id').AsString);
        Video.Description := Query.FieldByName('CONTEUDO').AsString;
        Video.Content := TNetEncoding.Base64.DecodeStringToBytes(Query.FieldByName('CONTEUDO').AsString);
        Video.DataInclusao := Query.FieldByName('DATA_INCLUSAO').AsString;

        JSONArray.AddElement(TJson.ObjectToJsonObject(Video));
        Query.Next;
      end;

      Result := JSONArray;
    except
      JSONArray.Free;
      raise;
    end;
  finally
    Query.Free;
  end;
end;

class function TServerController.GetServer(AID: TGUID): TJSONObject;
begin
  Result := TJson.ObjectToJsonObject(FindServerByID(AID));
end;

class function TServerController.GetVideo(ServerID, VideoID: TGUID): TJSONObject;
begin
  Result := TJson.ObjectToJsonObject(FindVideoByIDs(ServerID, VideoID));
end;

class procedure TServerController.InitializeConnection;
begin
  CoInitialize(nil);
  try
    if not Assigned(FConnection) then
    begin
      FConnection := TADOConnection.Create(nil);
      FConnection.ConnectionString := 'Provider=SQLOLEDB;Server=DESKTOP-LQTA0BU\SQLEXPRESS;Database=DadosServidorDelphi;Trusted_Connection=yes;';
      FConnection.LoginPrompt := False;
      FConnection.Connected := True;
    end;
  finally
    CoUninitialize;
  end;
end;

class function TServerController.UpdateServer(AID: TGUID; AName, AIPAddress: string;
  AIPPort: Integer): TJSONObject;
var
  Query: TADOQuery;
  RowsAffected: Integer;
  Servidor: TServer;
begin
  InitializeConnection;

  Query := TADOQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'UPDATE SERVIDOR SET NOME = :Name, IP_ADDRESS = :IPAddress, IP_PORT = :IPPort WHERE Id = :ID';
    Query.Parameters.ParamByName('Name').Value := AName;
    Query.Parameters.ParamByName('IPAddress').Value := AIPAddress;
    Query.Parameters.ParamByName('IPPort').Value := AIPPort;
    Query.Parameters.ParamByName('ID').Value := AID.ToString;
    RowsAffected := Query.ExecSQL;

    if RowsAffected > 0 then
    begin
      Result := TJson.ObjectToJsonObject(FindServerByID(AID));
    end
    else
      Result := nil;
  finally
    Query.Free;
  end;
end;

end.

