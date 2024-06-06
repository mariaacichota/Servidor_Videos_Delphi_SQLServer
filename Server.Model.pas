unit Server.Model;

interface

uses
  System.SysUtils, System.Classes, Videos.Model, System.Generics.Collections,
  FireDAC.Comp.Client, FireDAC.Stan.Param;

type
  TServer = class
  private
    FID: TGUID;
    FName: string;
    FIPAddress: string;
    FIPPort: Integer;
    FVideoList: TObjectList<TVideo>;
  public
    constructor Create;
    destructor Destroy; override;
    property ID: TGUID read FID write FID;
    property Name: string read FName write FName;
    property IPAddress: string read FIPAddress write FIPAddress;
    property IPPort: Integer read FIPPort write FIPPort;
  end;

var
  ServerList: TList<TServer>;

implementation


constructor TServer.Create;
begin
  inherited;
end;

destructor TServer.Destroy;
begin
  inherited;
end;


initialization
  ServerList := TList<TServer>.Create;

finalization
  ServerList.Free;

end.

