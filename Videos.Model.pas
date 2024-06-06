unit Videos.Model;

interface

uses
  System.SysUtils;

type
  TVideo = class
  private
    FId: TGUID;
    FDescricao: String;
    FConteudo: TBytes;
    FDataInclusao: String;

  public
    property Id: TGUID read FID write FID;
    property Descricao: String read FDescricao write FDescricao;
    property Conteudo: TBytes read FConteudo write FConteudo;
    property DataInclusao: String read FDataInclusao write FDataInclusao;
  end;

implementation

end.
