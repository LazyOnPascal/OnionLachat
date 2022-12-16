unit ChatContact;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ChatMessageList,
  ChatConnection, LbRSA;

type

  EChatContact = class(Exception);

  { TChatContact }

  TChatContact = class
  private
    FUser: TObject;
    FContactCritcalSection: TRTLCriticalSection;
    FMessages: TChatMessageList;
    FGeneralConnection: TChatConnection;
    FContactRSA: TLbRSA;
    FSessionKey: string;
    FContactLink: string;
    FAccepted: boolean;

  private
    procedure Init(aUser: TObject);

  public
    constructor Create(aUser: TObject; aLink: string);
    constructor Create(aUser: TObject; aSocket: longint);
    constructor LoadFromStream(aUser: TObject; aStream: TStream);
    destructor Destroy; override;
  public
    procedure Reconnect;
    procedure AcceptToReconnect(aSocket: longint);
    procedure LockCriticalSection;
    procedure UnlockCriticalSection;
    procedure PackToStream(aStream: TStream);
    procedure SetMaxProtocolVersion(maxTT, maxMC: DWORD);

  public
    property Messages: TChatMessageList read FMessages;
    property ContactRSAKey: TLbRSA read FContactRSA;
    property SessionKey: string read FSessionKey write FSessionKey;
    property ContactLink: string
      read FContactLink write FContactLink;
    property User: TObject read FUser;
    property Connection: TChatConnection read FGeneralConnection;
    property Accepted: boolean read FAccepted;

  end;

implementation

uses
  LbAsym, ChatFunctions, Sockets;

{ TChatContact }

procedure TChatContact.Init(aUser: TObject);
begin
  inherited Create;
  InitCriticalSection(FContactCritcalSection);
  FMessages := TChatMessageList.Create(FContactCritcalSection);
  FContactRSA := TLbRSA.Create(nil, '', aks128);
  FUser := aUser;
end;

constructor TChatContact.Create(aUser: TObject; aLink: string);
begin
  self.Init(aUser);
  FContactLink := aLink;
  FAccepted := False;
  FGeneralConnection :=
    TChatConnection.ConnectToNewLink(aLink, self);
end;

constructor TChatContact.Create(aUser: TObject; aSocket: longint);
begin
  self.Init(aUser);
  FAccepted := True;
  FGeneralConnection :=
    TChatConnection.AcceptNewSocket(aSocket, self);
end;

constructor TChatContact.LoadFromStream(aUser: TObject;
  aStream: TStream);
begin
  inherited Create;
  InitCriticalSection(FContactCritcalSection);
  FUser := aUser;

  FContactLink := aStream.ReadAnsiString;
  FAccepted := boolean(aStream.ReadByte);
  FContactRSA := TLbRSA.LoadFromStream(aStream);
  FMessages := TChatMessageList.LoadFromStream(
    FContactCritcalSection, aStream);
  FGeneralConnection := TChatConnection.ReconnectSuspended(self);
end;

procedure TChatContact.PackToStream(aStream: TStream);
begin
  aStream.WriteAnsiString(FContactLink);
  aStream.WriteByte(byte(FAccepted));
  FContactRSA.PackToStream(aStream);
  FMessages.PackToStream(aStream);
end;

procedure TChatContact.SetMaxProtocolVersion(maxTT, maxMC: DWORD);
begin
  { TODO : using this data?? }
end;

destructor TChatContact.Destroy;
begin
  if not FGeneralConnection.Finished then
    FGeneralConnection.Terminate;
  while not FGeneralConnection.Finished do
        Sleep(10);
  DoneCriticalSection(FContactCritcalSection);
  FContactRSA.Free;
  FMessages.Free;
  FGeneralConnection.Free;
  inherited;
end;

procedure TChatContact.Reconnect;
begin
  if FGeneralConnection.Suspended then
  begin
    FGeneralConnection.Start;
    exit;
  end;
  if FGeneralConnection.Finished then
  begin
    FGeneralConnection.Free;
    FGeneralConnection := TChatConnection.Reconnect(self);
  end;
end;

procedure TChatContact.AcceptToReconnect(aSocket: longint);
begin

  if Assigned(FGeneralConnection) and
    FGeneralConnection.Connected then
  begin
    ProgramLogError('Sock ' + IntToStr(aSocket) +
      ' try reconnect to always connected contact (' +
      Self.ContactRSAKey.Name + ')');
    CloseSocket(aSocket);
    Exit;
  end;

  if Assigned(FGeneralConnection) then
  begin
    if not FGeneralConnection.Finished then
      FGeneralConnection.Terminate;
    FGeneralConnection.Free;
  end;

  FGeneralConnection :=
    TChatConnection.AcceptForReconnect(aSocket, self);

end;

procedure TChatContact.LockCriticalSection;
begin
  EnterCriticalSection(FContactCritcalSection);
end;

procedure TChatContact.UnlockCriticalSection;
begin
  LeaveCriticalSection(FContactCritcalSection);
end;


end.
