unit ChatContactList;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  ChatContact;

type

  { TChatContactList }

  TChatContactList = class(TFPList)
  private
    function Get(Index: integer): TChatContact;
  public
    constructor Create;
    destructor Destroy; override;
  public
    function Add(aContact: TChatContact): integer;
  public
    property Items[Index: integer]: TChatContact read Get; default;
  end;

implementation

uses
  ChatTypes;

{ TChatContactList }

function TChatContactList.Get(Index: integer): TChatContact;
begin
  Result := TChatContact(inherited get(Index));
end;

constructor TChatContactList.Create;
begin
  inherited Create;
end;

destructor TChatContactList.Destroy;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    Items[I].Free;
  end;
  inherited Destroy;
end;

function TChatContactList.Add(aContact: TChatContact): integer;
begin
  Result := IndexOf(aContact);
  if Result <> -1 then
  begin
    raise EChatException.Create('Try to add contact(' + aContact.Name + ') to list twice ');
  end;
  for Result := 0 to Count - 1 do
  begin
    if Items[Result].Link = aContact.Link then
    begin
      raise EChatException.Create('Try to add contact with link(' +
        aContact.Link + ') to list twice ');
    end;
  end;
  Result := inherited Add(aContact);
end;

end.
