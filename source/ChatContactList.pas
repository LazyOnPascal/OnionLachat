unit ChatContactList;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ChatContact;

type

  TOnAddContact = procedure(aContact: TChatContact) of object;
  TOnDeleteContact = procedure(aContact: TChatContact) of object;

  { TChatContactList }

  TChatContactList = class(TFPList)
  private
    //FUserOwner: TObject;
    FOnAddProc: TOnAddContact;
    FOnDelProc: TOnDeleteContact;
  private
    function Get(Index: integer): TChatContact;
  public
    constructor Create;
    constructor LoadFromStream(aUser: TObject; aStream: TStream);
    destructor Destroy; override;
  public
    function Add(aContact: TChatContact): integer;
    procedure CheckForReconnect;
    procedure Lock;
    procedure UnLock;
    procedure PackToStream(aStream: TStream);
    procedure SetProc(aOnAddProc: TOnAddContact;
      aOnDelProc: TOnDeleteContact);
  public
    property Items[Index: integer]: TChatContact read Get; default;
  end;

implementation

{ TChatContactList }

function TChatContactList.Get(Index: integer): TChatContact;
begin
  Result := TChatContact(inherited get(Index));
end;

constructor TChatContactList.Create;
begin
  inherited Create;
  FOnAddProc := nil;
  FOnDelProc := nil;
end;

constructor TChatContactList.LoadFromStream(aUser: TObject;
  aStream: TStream);
var
  I, countContacts: integer;
begin
  self.Create;
  countContacts := aStream.ReadDWord;
  for I := 0 to countContacts - 1 do
  begin
    self.Add(TChatContact.LoadFromStream(aUser, aStream));
  end;
end;

procedure TChatContactList.PackToStream(aStream: TStream);
var
  I: integer;
begin
  aStream.WriteDWord(Count);
  for I := 0 to Count - 1 do
  begin
    Items[I].PackToStream(aStream);
  end;
end;

procedure TChatContactList.SetProc(aOnAddProc: TOnAddContact;
  aOnDelProc: TOnDeleteContact);
begin
  FOnAddProc := aOnAddProc;
  FOnDelProc := aOnDelProc;
end;

destructor TChatContactList.Destroy;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    if not (FOnDelProc = nil) then FOnDelProc(Items[I]);
    Items[I].Free;
  end;
  inherited Destroy;
end;

function TChatContactList.Add(aContact: TChatContact): integer;
var
  I: integer;
  isOld: boolean;
begin
  isOld := False;
  Result := -1;
  for I := 0 to Count - 1 do
  begin
    if (Items[I].ContactLink = aContact.ContactLink) then
    begin
      isOld := True;
      break;
    end;
  end;

  if not IsOld then
  begin
    //aContact.Reconnect;
    Result := inherited Add(aContact);
    if not (FOnAddProc = nil) then FOnAddProc(aContact);
  end;
end;

procedure TChatContactList.CheckForReconnect;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    if not Items[I].Connection.Connected then
      Items[I].Reconnect;
  end;
end;

procedure TChatContactList.Lock;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    Items[I].LockCriticalSection;
  end;
end;

procedure TChatContactList.UnLock;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    Items[I].UnlockCriticalSection;
  end;
end;

end.
