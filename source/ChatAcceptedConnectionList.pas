unit ChatAcceptedConnectionList;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  ChatAcceptedConnection,
  PollList;

type

  { TChatAcceptedConnectionList }

  TChatAcceptedConnectionList = class(TFPList)
  private
    function Get(Index: integer): TChatAcceptedConnection;
  public
    constructor Create;
    destructor Destroy; override;
  public
    function Add(aConnection: TChatAcceptedConnection): integer;
    procedure AddNewToPoll(aPoll: TPollList);
    procedure TimeOut;
  public
    property Items[Index: integer]: TChatAcceptedConnection read Get; default;
  end;

implementation

{ TChatAcceptedConnectionList }

function TChatAcceptedConnectionList.Get(Index: integer): TChatAcceptedConnection;
begin
  Result := TChatAcceptedConnection(inherited get(Index));
end;

constructor TChatAcceptedConnectionList.Create;
begin
  inherited Create;
end;

destructor TChatAcceptedConnectionList.Destroy;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    if assigned(Items[I]) then Items[I].Free;
  end;
  inherited Destroy;
end;

function TChatAcceptedConnectionList.Add(
  aConnection: TChatAcceptedConnection): integer;
begin
  Result := inherited Add(aConnection);
end;

procedure TChatAcceptedConnectionList.AddNewToPoll(aPoll: TPollList);
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    if Items[I].New then
    begin
      aPoll.Add(Items[I].ChatSocket.Poll);;
      Items[I].New := false;
    end;
  end;
end;

procedure TChatAcceptedConnectionList.TimeOut;
var
  I: integer;
begin
  // удаляем все соединения просрочившие таймаут
  I := 0;
  while not (I > (Count - 1)) do
  begin
    if Items[I].IsTimeOut then
    begin
      Items[I].Free;
      Delete(I);
    end else
    begin
      Inc(I);
    end;
  end;
end;

end.
