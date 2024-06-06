unit Server.View;

interface

uses
  Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.AppEvnts, Vcl.StdCtrls, IdHTTPWebBrokerBridge, IdGlobal, Web.HTTPApp,
  Vcl.FormTabsBar, Vcl.ExtCtrls, Server.Controller, Vcl.TitleBarCtrls;

type
  TfrmPrincipalServer = class(TForm)
    ButtonStart: TButton;
    ButtonStop: TButton;
    EditPort: TEdit;
    lblPort: TLabel;
    ApplicationEvents1: TApplicationEvents;
    ButtonOpenBrowser: TButton;
    OpenDialog1: TOpenDialog;
    pnlGeral: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
    procedure ButtonStartClick(Sender: TObject);
    procedure ButtonStopClick(Sender: TObject);
    procedure ButtonOpenBrowserClick(Sender: TObject);
    function VideoToBase64(const AFileName: string): string;
    procedure SendVideoToServer(const ServerID, Description, VideoBase64, InclusionDate: string);
  private
    FServer: TIdHTTPWebBrokerBridge;
    procedure StartServer;
  public
    { Public declarations }
  end;

var
  frmPrincipalServer: TfrmPrincipalServer;

implementation

{$R *.dfm}

uses
{$IFDEF MSWINDOWS}
  WinApi.Windows, Winapi.ShellApi,
{$ENDIF}
  Datasnap.DSSession,
  System.Generics.Collections, System.JSON, REST.Json, IdHTTP, IdSSLOpenSSL, System.NetEncoding,
  Server.Model;

procedure TfrmPrincipalServer.ApplicationEvents1Idle(Sender: TObject; var Done: Boolean);
begin
  ButtonStart.Enabled := not FServer.Active;
  ButtonStop.Enabled := FServer.Active;
  EditPort.Enabled := not FServer.Active;
end;

procedure TfrmPrincipalServer.ButtonOpenBrowserClick(Sender: TObject);
{$IFDEF MSWINDOWS}
var
  LURL: string;
{$ENDIF}
begin
  StartServer;
{$IFDEF MSWINDOWS}
  LURL := Format('http://localhost:%s', [EditPort.Text]);
  ShellExecute(0,
        nil,
        PChar(LURL), nil, nil, SW_SHOWNOACTIVATE);
{$ENDIF}
end;

procedure TfrmPrincipalServer.ButtonStartClick(Sender: TObject);
begin
  StartServer;
end;

procedure TerminateThreads;
begin
  if TDSSessionManager.Instance <> nil then
    TDSSessionManager.Instance.TerminateAllSessions;
end;

procedure TfrmPrincipalServer.ButtonStopClick(Sender: TObject);
begin
  TerminateThreads;
  FServer.Active := False;
  FServer.Bindings.Clear;
end;

procedure TfrmPrincipalServer.FormCreate(Sender: TObject);
begin
  FServer := TIdHTTPWebBrokerBridge.Create(Self);
end;

procedure TfrmPrincipalServer.SendVideoToServer(const ServerID, Description, VideoBase64,
  InclusionDate: string);
var
  HTTPClient: TIdHTTP;
  SSLHandler: TIdSSLIOHandlerSocketOpenSSL;
  JSONObj: TJSONObject;
  Response: string;
begin
  HTTPClient := TIdHTTP.Create(nil);
  SSLHandler := TIdSSLIOHandlerSocketOpenSSL.Create(nil);
  try
    HTTPClient.IOHandler := SSLHandler;
    HTTPClient.Request.ContentType := 'application/json';

    JSONObj := TJSONObject.Create;
    try
      JSONObj.AddPair('server_id', ServerID);
      JSONObj.AddPair('description', Description);
      JSONObj.AddPair('content', VideoBase64);
      JSONObj.AddPair('inclusion_date', InclusionDate);

      HTTPClient.Request.Connection := 'close';
      Response := HTTPClient.Post('http://localhost:8080/api/servers/video', TStringStream.Create(JSONObj.ToString, TEncoding.UTF8));
    finally
      JSONObj.Free;
    end;
  finally
    SSLHandler.Free;
    HTTPClient.Free;
  end;
end;

procedure TfrmPrincipalServer.StartServer;
begin
  if not FServer.Active then
  begin
    FServer.Bindings.Clear;
    FServer.DefaultPort := StrToInt(EditPort.Text);
    FServer.Active := True;
  end;
end;

function TfrmPrincipalServer.VideoToBase64(const AFileName: string): string;
var
  VideoStream: TMemoryStream;
  Base64Encoder: TBase64Encoding;
begin
  VideoStream := TMemoryStream.Create;
  try
    VideoStream.LoadFromFile(AFileName);
    Base64Encoder := TBase64Encoding.Create;
    try
      Result := Base64Encoder.EncodeBytesToString(VideoStream.Memory, VideoStream.Size);
    finally
      Base64Encoder.Free;
    end;
  finally
    VideoStream.Free;
  end;
end;

end.
