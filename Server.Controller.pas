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
    class function CreateServer(nomeServidor, ipAddress: string; ipPort: Integer): TJSONObject;
    class function CreateVideo(Server: TServer; descricao, conteudo: String; dataInclusao: TDateTime): TJSONObject;
    class function UpdateServer(idServidor: TGUID; nomeServidor, ipAddress: string; ipPort: Integer): TJSONObject;
    class function DeleteServer(idServidor: TGUID): Boolean;
    class function DeleteVideo(idServidor, idVideo: TGUID): Boolean;
    class function GetServer(idServidor: TGUID): TJSONObject;
    class function GetVideo(idServidor, idVideo: TGUID): TJSONObject;
    class function CheckServerAvailability(idServidor: TGUID): Boolean;
    class function GetAllServers: TJSONArray;
    class function GetAllVideos: TJSONArray;
    class function DownloadBinaryVideo(Video: TVideo): TStream;
    class function DeleteVideoRecyclerProcess(dias: Integer): Boolean;

    class function FindServerByID(idServidor: TGUID): TServer;
    class function FindVideoByIDs(idServidor, idVideo: TGUID): TVideo;
  end;

{$METHODINFO OFF}

implementation

uses
  System.Generics.Collections, System.SysUtils;

{ TServerController }

class function TServerController.CheckServerAvailability(idServidor: TGUID): Boolean;
var
  Servidor: TServer;
  TCPClient: TIdTCPClient;
begin
  Servidor := FindServerByID(idServidor);
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

class function TServerController.CreateServer(nomeServidor, ipAddress: string;
  ipPort: Integer): TJSONObject;
var
  query: TADOquery;
  idServidor: TGUID;
begin
  try
    InitializeConnection;
    idServidor := TGUID.NewGuid;
    query := TADOquery.Create(nil);
    try
      query.Connection := FConnection;
      query.SQL.Text := 'INSERT INTO SERVIDOR (Id, NOME, IP_ADDRESS, IP_PORT) VALUES (:Id, :Nome, :IPAddress, :IPPort)';
      query.Parameters.ParamByName('Id').Value := idServidor.ToString;
      query.Parameters.ParamByName('Nome').Value := nomeServidor;
      query.Parameters.ParamByName('IPAddress').Value := ipAddress;
      query.Parameters.ParamByName('IPPort').Value := ipPort;
      query.ExecSQL;

      Result := TJSONObject.Create;
      Result.AddPair('Id', TJSONString.Create(GuidToString(idServidor)));
      Result.AddPair('Nome', TJSONString.Create(nomeServidor));
      Result.AddPair('IPAddress', TJSONString.Create(ipAddress));
      Result.AddPair('IPPort', TJSONNumber.Create(ipPort));
    except
      Result.Free;
      raise;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end;

class function TServerController.CreateVideo(Server: TServer; descricao,
  conteudo: String; dataInclusao: TDateTime): TJSONObject;
var
  query: TADOquery;
  idVideo: TGUID;
  videoContent: TBytes;
  InclusionDateStr: string;
begin
  try
    InitializeConnection;
    idVideo := TGUID.NewGuid;
    videoContent := TNetEncoding.Base64.DecodeStringToBytes(conteudo);
    InclusionDateStr := FormatDateTime('yyyy-mm-dd hh:nn:ss', dataInclusao);

    query := TADOquery.Create(nil);
    try
      query.Connection := FConnection;
      query.SQL.Text := 'INSERT INTO VIDEOS (Id, DESCRICAO, CONTEUDO, SERVIDOR_ID, DATA_INCLUSAO) VALUES (:Id, :Descricao, :Conteudo, :ServdorId, :DataInclusao)';
      query.Parameters.ParamByName('Id').Value := idVideo.ToString;
      query.Parameters.ParamByName('Descricao').Value := descricao;
      query.Parameters.ParamByName('Conteudo').Value := videoContent;
      query.Parameters.ParamByName('ServdorId').Value := Server.ID.ToString;
      query.Parameters.ParamByName('DataInclusao').Value := dataInclusao;
      query.ExecSQL;

      Result := TJSONObject.Create;
      Result.AddPair('Id', TJSONString.Create(GuidToString(idVideo)));
      Result.AddPair('Descricao', TJSONString.Create(descricao));
      Result.AddPair('Conteudo', TJSONString.Create(conteudo));
      Result.AddPair('ServdorId', TJSONString.Create(Server.Id.ToString));
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

class function TServerController.DeleteServer(idServidor: TGUID): Boolean;
var
  query: TADOquery;
  rowsAffected: Integer;
begin
  InitializeConnection;

  query := TADOquery.Create(nil);
  try
    query.Connection := FConnection;
    query.SQL.Text := 'DELETE FROM SERVIDOR WHERE Id = :ID';
    query.Parameters.ParamByName('ID').Value := idServidor.ToString;
    rowsAffected := query.ExecSQL;

    Result := rowsAffected > 0;
  finally
    query.Free;
  end;
end;

class function TServerController.DeleteVideo(idServidor, idVideo: TGUID): Boolean;
var
  query: TADOquery;
  rowsAffected: Integer;
begin
  InitializeConnection;

  query := TADOquery.Create(nil);
  try
    query.Connection := FConnection;
    query.SQL.Text := 'DELETE FROM VIDEOS WHERE Id = :ID AND SERVIDOR_ID = :idServidor';
    query.Parameters.ParamByName('ID').Value := idVideo.ToString;
    query.Parameters.ParamByName('idServidor').Value := idServidor.ToString;
    rowsAffected := query.ExecSQL;

    Result := rowsAffected > 0;
  finally
    query.Free;
  end;
end;

class function TServerController.DeleteVideoRecyclerProcess(
  dias: Integer): Boolean;
var
  query: TADOquery;
  rowsAffected: Integer;
  dateLimit: TDateTime;
begin
  InitializeConnection;

  dateLimit := IncDay(Now, -dias);

  query := TADOquery.Create(nil);
  try
    query.Connection := FConnection;
    query.SQL.Text := 'DELETE FROM VIDEOS WHERE DATA_INCLUSAO < :DateLimit';
    query.Parameters.ParamByName('DateLimit').Value := DateLimit;
    rowsAffected := query.ExecSQL;

    Result := rowsAffected > 0;
  finally
    query.Free;
  end;
end;

class function TServerController.DownloadBinaryVideo(Video: TVideo): TStream;
begin
  Result := TMemoryStream.Create;
  try
    if Length(Video.Conteudo) > 0 then
    begin
      Result.WriteBuffer(Video.Conteudo[0], Length(Video.Conteudo));
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

class function TServerController.FindServerByID(idServidor: TGUID): TServer;
var
  query: TADOquery;
begin
  InitializeConnection;

  query := TADOquery.Create(nil);
  try
    query.Connection := FConnection;
    query.SQL.Text := 'SELECT Id, NOME, IP_ADDRESS, IP_PORT FROM SERVIDOR WHERE ID = :ID';
    query.Parameters.ParamByName('ID').Value := idServidor.ToString;
    query.Open;

    if not query.Eof then
    begin
      Result := TServer.Create;
      Result.Id := StringToGUID(query.FieldByName('Id').AsString);
      Result.Nome := query.FieldByName('NOME').AsString;
      Result.IpAddress := query.FieldByName('IP_ADDRESS').AsString;
      Result.IpPort := query.FieldByName('IP_PORT').AsInteger;
    end
    else
      Result := nil;
  finally
    query.Free;
  end;
end;

class function TServerController.FindVideoByIDs(idServidor, idVideo: TGUID): TVideo;
var
  query: TADOquery;
begin
  InitializeConnection;

  query := TADOquery.Create(nil);
  try
    query.Connection := FConnection;
    query.SQL.Text := 'SELECT Id, DESCRICAO, CONTEUDO, SERVIDOR_ID, DATA_INCLUSAO FROM VIDEOS WHERE Id = :ID AND SERVIDOR_ID = :idServidor';
    query.Parameters.ParamByName('ID').Value := idVideo.ToString;
    query.Parameters.ParamByName('idServidor').Value := idServidor.ToString;
    query.Open;

    if not query.Eof then
    begin
      Result := TVideo.Create;
      Result.ID := StringToGUID(query.FieldByName('Id').AsString);
      Result.Descricao := query.FieldByName('DESCRICAO').AsString;
      Result.Conteudo := TNetEncoding.Base64.DecodeStringToBytes(query.FieldByName('CONTEUDO').AsString);
      Result.DataInclusao := query.FieldByName('DATA_INCLUSAO').AsString;
    end
    else
      Result := nil;
  finally
    query.Free;
  end;
end;

class function TServerController.GetAllServers: TJSONArray;
var
  Servidor: TServer;
  JSONArray: TJSONArray;
  query: TADOquery;
begin
  InitializeConnection;

  query := TADOquery.Create(nil);
  try
    query.Connection := FConnection;
    query.SQL.Text := 'SELECT Id, NOME, IP_ADDRESS, IP_PORT FROM SERVIDOR';
    query.Open;

    JSONArray := TJSONArray.Create;
    try
      while not query.Eof do
      begin
        Servidor := TServer.Create;
        Servidor.Id := StringToGUID(query.FieldByName('Id').AsString);
        Servidor.Nome := query.FieldByName('NOME').AsString;
        Servidor.IpAddress := query.FieldByName('IP_ADDRESS').AsString;
        Servidor.IpPort := query.FieldByName('IP_PORT').AsInteger;

        JSONArray.AddElement(TJson.ObjectToJsonObject(Servidor));
        query.Next;
      end;

      Result := JSONArray;
    except
      JSONArray.Free;
      raise;
    end;
  finally
    query.Free;
  end;
end;

class function TServerController.GetAllVideos: TJSONArray;
var
  Video: TVideo;
  JSONArray: TJSONArray;
  query: TADOquery;
begin
  InitializeConnection;

  query := TADOquery.Create(nil);
  try
    query.Connection := FConnection;
    query.SQL.Text := 'SELECT Id, DESCRICAO, CONTEUDO, SERVIDOR_ID, DATA_INCLUSAO FROM VIDEOS';
    query.Open;

    JSONArray := TJSONArray.Create;
    try
      while not query.Eof do
      begin
        Video := TVideo.Create;
        Video.Id := StringToGUID(query.FieldByName('Id').AsString);
        Video.Descricao := query.FieldByName('DESCRICAO').AsString;
        Video.Conteudo := TNetEncoding.Base64.DecodeStringToBytes(query.FieldByName('CONTEUDO').AsString);
        Video.DataInclusao := query.FieldByName('DATA_INCLUSAO').AsString;

        JSONArray.AddElement(TJson.ObjectToJsonObject(Video));
        query.Next;
      end;

      Result := JSONArray;
    except
      JSONArray.Free;
      raise;
    end;
  finally
    query.Free;
  end;
end;

class function TServerController.GetServer(idServidor: TGUID): TJSONObject;
begin
  Result := TJson.ObjectToJsonObject(FindServerByID(idServidor));
end;

class function TServerController.GetVideo(idServidor, idVideo: TGUID): TJSONObject;
begin
  Result := TJson.ObjectToJsonObject(FindVideoByIDs(idServidor, idVideo));
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

class function TServerController.UpdateServer(idServidor: TGUID; nomeServidor, ipAddress: string;
  ipPort: Integer): TJSONObject;
var
  query: TADOquery;
  rowsAffected: Integer;
  Servidor: TServer;
begin
  InitializeConnection;

  query := TADOquery.Create(nil);
  try
    query.Connection := FConnection;
    query.SQL.Text := 'UPDATE SERVIDOR SET NOME = :Name, IP_ADDRESS = :IPAddress, IP_PORT = :IPPort WHERE Id = :ID';
    query.Parameters.ParamByName('Name').Value := nomeServidor;
    query.Parameters.ParamByName('IPAddress').Value := ipAddress;
    query.Parameters.ParamByName('IPPort').Value := ipPort;
    query.Parameters.ParamByName('ID').Value := idServidor.ToString;
    rowsAffected := query.ExecSQL;

    if rowsAffected > 0 then
    begin
      Result := TJson.ObjectToJsonObject(FindServerByID(idServidor));
    end
    else
      Result := nil;
  finally
    query.Free;
  end;
end;

end.

