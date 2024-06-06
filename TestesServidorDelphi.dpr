program TestesServidorDelphi;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  DUnitX.Loggers.XML.NUnit,
  DUnitX.Loggers.XML.JUnit,
  IdHTTPServer,
  IdSSLOpenSSL,
  Server.Testes in 'Testes\Server.Testes.pas';

var
  Server: TIdHTTPServer;
  Runner: ITestRunner;
  ConsoleLogger: TDUnitXConsoleLogger;

function CreateSSLHandler: TIdServerIOHandlerSSLOpenSSL;
begin
  Result := TIdServerIOHandlerSSLOpenSSL.Create(nil);
  Result.SSLOptions.Method := sslvTLSv1_2;
  Result.SSLOptions.Mode := sslmServer;
end;

begin
  try
    Writeln('Inicializando o servidor...');
    Server := TIdHTTPServer.Create(nil);
    try
      Server.IOHandler := CreateSSLHandler;

      Server.DefaultPort := 8080;
      Server.Active := True;
      Writeln('Servidor inicializado na porta 8080.');

      Writeln('Criando o runner de testes...');
      Runner := TDUnitX.CreateRunner;
      ConsoleLogger := TDUnitXConsoleLogger.Create(true);
      Runner.AddLogger(ConsoleLogger);

      Writeln('Executando os testes...');
      Runner.Execute;
      Writeln('Testes concluídos.');
    finally
      Server.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;

end.

