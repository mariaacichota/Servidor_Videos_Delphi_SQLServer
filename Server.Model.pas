unit Server.Model;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  FireDAC.Comp.Client, FireDAC.Stan.Param;

type
  TServer = class
  private
    FId: TGUID;
    FNome: string;
    FIpAddress: string;
    FIpPort: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    property Id: TGUID read FId write FId;
    property Nome: string read FNome write FNome;
    property IpAddress: string read FIpAddress write FIpAddress;
    property IpPort: Integer read FIpPort write FIpPort;
  end;

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

finalization

end.

