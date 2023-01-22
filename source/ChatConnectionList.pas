unit ChatConnectionList;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  ChatConnection;

type

  { TChatConnectionList }

  TChatConnectionList = class(TFPList)
  private
    function Get(Index: integer): TChatConnection;
  public
    constructor Create;
    destructor Destroy; override;
  public
    function Add(aConnection: TChatConnection): integer;
  public
    property Items[Index: integer]: TChatConnection read Get; default;
  end;

implementation

{ TChatConnectionList }

function TChatConnectionList.Get(Index: integer): TChatConnection;
begin
  Result := TChatConnection(inherited get(Index));
end;

constructor TChatConnectionList.Create;
begin
  inherited Create;
end;

destructor TChatConnectionList.Destroy;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    Items[I].Free;
  end;
  inherited Destroy;
end;

function TChatConnectionList.Add(aConnection: TChatConnection): integer;
begin
  Result := inherited Add(aConnection);
end;

end.

