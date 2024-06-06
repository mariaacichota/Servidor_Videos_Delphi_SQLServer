program ServidorDelphi;
{$APPTYPE GUI}

uses
  Vcl.Forms,
  Web.WebReq,
  IdHTTPWebBrokerBridge,
  Server.Container in 'Server.Container.pas' {ServerContainer: TDataModule},
  Server.Controller in 'Server.Controller.pas',
  Server.Model in 'Server.Model.pas',
  Server.View in 'Server.View.pas' {frmPrincipalServer},
  Videos.Model in 'Videos.Model.pas',
  Web.Module in 'Web.Module.pas' {WebModule1: TWebModule};

{$R *.res}

begin
  if WebRequestHandler <> nil then
    WebRequestHandler.WebModuleClass := WebModuleClass;
  Application.Initialize;
  Application.CreateForm(TfrmPrincipalServer, frmPrincipalServer);
  Application.Run;
end.
