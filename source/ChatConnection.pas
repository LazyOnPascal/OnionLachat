unit ChatConnection;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ChatMessageList;

const
  SLEEP_IF_NO_TRANSFER_MS = 1000;
  SLEEP_IF_NO_CONNECT_MS = 1000;

type

  EChatConnection = class(Exception);

  TConnectionType = (TCT_NewToLink, TCT_NewAcceptSocket,
    TCT_Reconnect, TCT_AcceptReconnect);

  { TChatConnection }

  TChatConnection = class(TThread)
  private
    FCType: TConnectionType;
    FConnected: boolean;
    FHost: string;
    FHostPort: word;
    FSocksPort: word;
    FSock: longint;

    FContact: TObject;
    FReasonOfTerminate: string;
  private
    procedure Init(aContact: TObject; CreateSuspended: boolean);
    procedure NewToLink;
    procedure NewAcceptSocket;
    procedure Reconnect;
    procedure AcceptReconnect;
    procedure ConnectionLoop;

  public
    constructor ConnectToNewLink(aLink: string; aContact: TObject);
    constructor AcceptNewSocket(aSock: longint; aContact: TObject);
    constructor Reconnect(aContact: TObject);
    constructor ReconnectSuspended(aContact: TObject);
    constructor AcceptForReconnect(aSock: longint;
      aContact: TObject);

    destructor Destroy; override;
  protected
    procedure Execute; override;
  public
    property ReasonOfTerminate: string read FReasonOfTerminate;
    property Connected: boolean read FConnected;

  end;

implementation

uses
  Sockets, ChatContact, ChatProtocol, LbRandom, ChatUser,
  ChatFunctions;

{ TChatConnection }

procedure TChatConnection.Init(aContact: TObject;
  CreateSuspended: boolean);
begin
  FContact := aContact;
  FConnected := False;
  FSocksPort := TChatUser(TChatContact(aContact).User).Tor.socksPort;
  inherited Create(CreateSuspended);
  self.priority := tpLower;
  self.FreeOnTerminate := False;
end;


constructor TChatConnection.ConnectToNewLink(aLink: string;
  aContact: TObject);
begin

  FCType := TCT_NewToLink;
  FHost := TorHostFromLink(aLink);
  FHostPort := TorOnionPortFromLink(aLink);
  FSock := fpSocket(AF_INET, SOCK_STREAM, IPPROTO_IP);
  ProgramLogInfo('ConnectToNewLink with sock ' + IntToStr(FSock));
  self.Init(aContact, False);

end;

constructor TChatConnection.AcceptNewSocket(aSock: longint;
  aContact: TObject);
begin

  FCType := TCT_NewAcceptSocket;
  FSock := aSock;
  ProgramLogInfo('AcceptNewSocket with sock ' + IntToStr(FSock));
  self.Init(aContact, False);

end;

constructor TChatConnection.Reconnect(aContact: TObject);
begin
  FCType := TCT_Reconnect;
  FHost := TorHostFromLink(TChatContact(aContact).ContactLink);
  FHostPort := TorOnionPortFromLink(
    TChatContact(aContact).ContactLink);
  ProgramLogInfo('Reconnect');
  self.Init(aContact, False);
end;

constructor TChatConnection.ReconnectSuspended(aContact: TObject);
begin
  FCType := TCT_Reconnect;
  FHost := TorHostFromLink(TChatContact(aContact).ContactLink);
  FHostPort := TorOnionPortFromLink(
    TChatContact(aContact).ContactLink);
  ProgramLogInfo('ReconnectSuspended');
  self.Init(aContact, True);
end;

constructor TChatConnection.AcceptForReconnect(aSock: longint;
  aContact: TObject);
begin
  FCType := TCT_AcceptReconnect;
  FSock := aSock;
  ProgramLogInfo('AcceptForReconnect with sock ' +
    IntToStr(FSock));
  self.Init(aContact, False);
end;

destructor TChatConnection.Destroy;
begin
  CloseSocket(FSock);
  inherited Destroy;
end;

procedure TChatConnection.Execute;
begin

  try

    try
      case FCType of
        TCT_NewToLink: NewToLink;
        TCT_NewAcceptSocket: NewAcceptSocket;
        TCT_Reconnect: Reconnect;
        TCT_AcceptReconnect: AcceptReconnect;
      end;
    except
      on E: EChatNet do
      begin
        FReasonOfTerminate := E.Message;
        Exit;
      end;
    end;

  finally

    FConnected := False;
    CloseSocket(FSock);
    ProgramLogInfo('Connection with ' + TChatContact(
      FContact).ContactRSAKey.Name + ' ,sock - ' +
      IntToStr(FSock) + ' closed "' + FReasonOfTerminate + '"');

  end;

end;


procedure TChatConnection.NewToLink;
var
  user: TChatUser;
  checkString: string;
begin

  user := TChatUser(TChatContact(FContact).User);

    while True do
    begin

      { реконнект к удаленному хосту}
      try
        self.FSock :=
          ConnectToSocks5Host(self.FHost, self.FHostPort,
          self.FSocksPort, self);
        if not (self.FSock = -1) then break;
      except
        Sleep(Random(SLEEP_IF_NO_CONNECT_MS));
      end;

      if Terminated then exit;

    end;

  {read in
  TChatUser.AcceptedNewSocked}
    SendIsNewContact(self.FSock);

    //share public keys
    WritePublicKey(self.FSock,
      user.Key);
    ReadPublicKey(self.FSock,
      TChatContact(FContact).ContactRSAKey);

    //check RSA
    checkString := CheckRSAReadString(self.FSock, user.Key);
    CheckRSAWriteString(
      self.FSock, checkString,
      TChatContact(FContact).ContactRSAKey);

    //read random session encription key
    ReadSessionKey(self.FSock, TChatContact(FContact));

    //send link to self
    WriteSelfLinkToSocket(self.FSock, TChatContact(FContact));

    //send version of protocol
    SendMaxProtocolVersion(self.FSock, TChatContact(FContact));
    ReadMaxProtocolVersion(self.FSock, TChatContact(FContact));

    ConnectionLoop;

end;

procedure TChatConnection.NewAcceptSocket;
var
  user: TChatUser;
  checkString: string;
begin

  user := TChatUser(TChatContact(FContact).User);

  //share public keys
  ReadPublicKey(self.FSock,
    TChatContact(FContact).ContactRSAKey);
  WritePublicKey(self.FSock, user.Key);

  //check RSA
  checkString := RandomString(10);
  CheckRSAWriteString(
    self.FSock, checkString,
    TChatContact(FContact).ContactRSAKey);
  if not (CheckRSAReadString(self.FSock, user.Key) =
    checkString) then
    raise EChatNet.Create('RSA check not passed');

  //set random session encription key
  SetSessionKey(self.FSock, TChatContact(FContact));

  ReadContactLinkFromSocket(self.FSock,
    TChatContact(FContact));

  //send version of protocol
  ReadMaxProtocolVersion(self.FSock, TChatContact(FContact));
  SendMaxProtocolVersion(self.FSock, TChatContact(FContact));


  ///////////////////////////
  ConnectionLoop;

end;

procedure TChatConnection.Reconnect;
var
  user: TChatUser;
  checkString: string;
begin

  user := TChatUser(TChatContact(FContact).User);

    while True do
    begin

      { реконнект к удаленному хосту}
      try
        self.FSock :=
          ConnectToSocks5Host(self.FHost, self.FHostPort,
          self.FSocksPort, self);
        if not (self.FSock = -1) then break;
      except
        Sleep(Random(SLEEP_IF_NO_CONNECT_MS));
      end;

      if Terminated then exit;

    end;

    {read in TChatUser.AcceptedNewSocked}
    SendIsOldContact(self.FSock);

    {read in TChatUser.AcceptedNewSocked}
    //send modulus of public key as id
    CheckRSAWriteString(self.FSock,
      user.Key.PublicKey.ModulusAsString,
      TChatContact(FContact).ContactRSAKey);


    //check RSA
    checkString := CheckRSAReadString(self.FSock, user.Key);
    CheckRSAWriteString(
      self.FSock, checkString,
      TChatContact(FContact).ContactRSAKey);


    //read random session encription key
    ReadSessionKey(self.FSock, TChatContact(FContact));

    //send version of protocol
    SendMaxProtocolVersion(self.FSock, TChatContact(FContact));
    ReadMaxProtocolVersion(self.FSock, TChatContact(FContact));

    ConnectionLoop;

end;

procedure TChatConnection.AcceptReconnect;
var
  user: TChatUser;
  checkString: string;
begin

  user := TChatUser(TChatContact(FContact).User);

  //check RSA
  checkString := RandomString(10);
  CheckRSAWriteString(
    self.FSock, checkString,
    TChatContact(FContact).ContactRSAKey);
  if not (CheckRSAReadString(self.FSock, user.Key) =
    checkString) then
    raise EChatNet.Create('RSA check not passed');

  //set random session encription key
  SetSessionKey(self.FSock, TChatContact(FContact));

  //send version of protocol
  ReadMaxProtocolVersion(self.FSock, TChatContact(FContact));
  SendMaxProtocolVersion(self.FSock, TChatContact(FContact));

  ConnectionLoop;

end;

procedure TChatConnection.ConnectionLoop;
var
  transfer: TTranferType;
begin

  FConnected := True;

  try

  while (not Terminated) do
  begin

    transfer := getTransfer(FSock);
    case TTranferType(transfer) of

      TTPresenseMessages: ReadMessagesFromSocket(
          FSock, TChatContact(FContact));

      TTNON: Sleep(SLEEP_IF_NO_TRANSFER_MS);

      else
        raise EChatNet.Create('Transfer type wrong');
    end;

    if TChatContact(FContact).Messages.HasMessagesToSend then
    begin
      ReportPresenceMessage(FSock);
      WriteMessagesToSocket(FSock, TChatContact(FContact));
    end;

  end;

  except
    on E : EChatNet do
    begin
      ProgramLogInfo('Message loop exception '+E.Message);
    end;
  end;

  CloseSocket(FSock);

end;




end.
