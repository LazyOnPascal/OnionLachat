unit ChatMessageList;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ChatMessage;

type

  EChatError = class(Exception);

  TOnAddMessage = procedure(aMessage: TChatMessage) of object;
  TOnDeleteMessage = procedure(aMessage: TChatMessage) of object;

  { TChatMessageList }

  TChatMessageList = class(TFPList)
  private
    FContactCritcalSection: TRTLCriticalSection;
    FOnAddMessage : TOnAddMessage;
    FOnDeleteMessage : TOnDeleteMessage;

  private
    function Get(Index: integer): TChatMessage;
  public
    constructor Create(aContactCritcalSection: TRTLCriticalSection);
    constructor LoadFromStream(aContactCritcalSection:
      TRTLCriticalSection; aStream: TStream);
    destructor Destroy; override;
  public
    function Add(aMessage: TChatMessage): integer;
    function HasMessagesToSend: boolean;
    procedure PackToStream(aStream: TStream);
    procedure SetProc(aOnAddProc: TOnAddMessage;
      aOnDelProc: TOnDeleteMessage);
  public
    property Items[Index: integer]: TChatMessage read Get; default;
  end;

implementation

{ TMessageList }

constructor TChatMessageList.Create(aContactCritcalSection:
  TRTLCriticalSection);
begin
  inherited Create;
  FOnAddMessage := nil;
  FOnDeleteMessage := nil;
  FContactCritcalSection := aContactCritcalSection;
end;

constructor TChatMessageList.LoadFromStream(
  aContactCritcalSection: TRTLCriticalSection; aStream: TStream);
var
  I, countMessages: integer;
  mc : TMessageCode;
begin
  self.Create(aContactCritcalSection);
  countMessages := aStream.ReadDWord;
  for I := 0 to countMessages - 1 do
  begin
    mc := TMessageCode(aStream.ReadByte);
    if mc = MC_TextMessage then
       self.Add(TTextMessage.LoadFromStream(aStream))
    else
       raise EChatError.Create('Bad type of message in database');
  end;
end;

procedure TChatMessageList.PackToStream(aStream: TStream);
var
  I: integer;
begin
  aStream.WriteDWord(Count);
  for I := 0 to Count - 1 do
  begin
    Items[I].PackToStream(aStream);
  end;
end;

procedure TChatMessageList.SetProc(aOnAddProc: TOnAddMessage;
  aOnDelProc: TOnDeleteMessage);
begin
  FOnAddMessage := aOnAddProc;
  FOnDeleteMessage := aOnDelProc;
end;

destructor TChatMessageList.Destroy;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    if not (FOnDeleteMessage = nil) then FOnDeleteMessage(Items[I]);
    Items[I].Free;
  end;
  inherited Destroy;
end;

function TChatMessageList.Get(Index: integer): TChatMessage;
begin
  Result := TChatMessage(inherited get(Index));
end;

function TChatMessageList.Add(aMessage: TChatMessage): integer;
begin
  EnterCriticalSection(FContactCritcalSection);
  if not (FOnAddMessage = nil) then FOnAddMessage(aMessage);
  Result := inherited Add(aMessage);
  LeaveCriticalSection(FContactCritcalSection);
end;

function TChatMessageList.HasMessagesToSend: boolean;
var
  I: integer;
begin
  Result := False;
  for I := 0 to Count - 1 do
  begin
    if not Items[I].Sended and (Items[I].Direction =
      MD_Outgoing) then
    begin
      Exit(True);
    end;
  end;
end;

end.
