unit ChatUser;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ChatLocalServer, TorLauncher,
  ChatContactList, LbRSA, LbAsym;

const
  FILE_DATA_BASE_VER_1 = 1;

type

  { TChatUser }

  TChatUser = class(TObject)
  private
    FPause: boolean;
    FConstructorError: boolean;
    FName: string;
    FServer: TChatServer;
    FTor: TTorLauncher;
    FContacts: TChatContactList;
    FUserKey: TLbRSA;

  public
    constructor Create(aName, aTorBinDir, aTorConfigDir: string;
      aServerPort, aSocksPort: word; aKeySize: TLbAsymKeySize;
      aBridges: TTorBridges);
    constructor LoadFromStream(aStream: TStream);
    destructor Destroy; override;
  public
    procedure Start;
    function getLink: string;
    procedure AcceptedNewSocked(aSocket: longint);
    procedure Pause;
    procedure Resume;
    procedure PackToStream(aStream: TStream);

  public
    property Name: string read FName write FName;
    property Server: TChatServer read FServer;
    property Tor: TTorLauncher read FTor;
    property Contacts: TChatContactList read FContacts;
    property Key: TLbRSA read FUserKey;
    property Error: boolean read FConstructorError;

  end;




implementation

uses
  Forms, ChatProtocol, ChatContact, ChatFunctions,
  Sockets, ChatMessageList;

{ TChatUser }

constructor TChatUser.Create(aName, aTorBinDir,
  aTorConfigDir: string;
  aServerPort, aSocksPort: word; aKeySize: TLbAsymKeySize;
  aBridges: TTorBridges);
begin
  inherited Create;
  FPause := False;
  FConstructorError := True;
  self.FName := aName;

  try
    FServer := TChatServer.Create(aServerPort, self);
    FContacts := TChatContactList.Create();
    FUserKey := TLbRSA.Create(nil, self.FName, aKeySize);

    FTor := TTorLauncher.Create(aTorBinDir, aTorConfigDir,
      aServerPort, aSocksPort, aBridges);

    FConstructorError := False;
  except
    on E: EChatServerException do
    begin
      ProgramLogError('Server lanch error ' + E.Message);
    end
    else
    begin
      ProgramLogError('Unknown error in ' + self.FName +
        ' constructor');
    end;
  end;

end;

constructor TChatUser.LoadFromStream(aStream: TStream);
begin

  inherited Create;
  FPause := False;
  FConstructorError := True;

  if not aStream.ReadQWord = FILE_DATA_BASE_VER_1 then
  begin
    ProgramLogError('Error in LoadFromStream load constructor');
    exit;
  end;


  try
    self.FName := aStream.ReadAnsiString;
    FUserKey := TLbRSA.LoadFromStream(aStream);
    FServer := TChatServer.LoadFromStream(aStream, self);
    FTor := TTorLauncher.LoadFromStream(aStream);
    FContacts := TChatContactList.LoadFromStream(self, aStream);
    FConstructorError := False;
  except
    ProgramLogError('Error in LoadFromStream load constructor');
  end;

end;

procedure TChatUser.PackToStream(aStream: TStream);
begin

  aStream.WriteQWord(FILE_DATA_BASE_VER_1);
  aStream.WriteAnsiString(FName);
  FUserKey.PackToStream(aStream);
  FServer.PackToStream(aStream);
  FTor.PackToStream(aStream);
  FContacts.PackToStream(aStream);

end;

destructor TChatUser.Destroy;
begin

  if assigned(FContacts) then FContacts.Free;
  if assigned(FTor) then FTor.Free;
  if assigned(FServer) and not FServer.Finished then
    FServer.Terminate;
  if assigned(FServer) then FServer.Free;
  if assigned(FUserKey) then FUserKey.Free;

  inherited Destroy;
end;

procedure TChatUser.Start;
begin
  try
    FServer.StartOfSockService;
    if FServer.Finished or FServer.Suspended then FServer.Start;
    if not FTor.process.Running then FTor.Execute;
  except
    FConstructorError := True;
  end;
end;

function TChatUser.getLink: string;
begin
  Result := LinkFromTorHostAndPort(FTor.host, FTor.onionPort);
end;

procedure TChatUser.AcceptedNewSocked(aSocket: longint);
var
  newContact: TChatContact;
  isNew: boolean;
  contactMod: string;
  I: integer;
begin

  while FPause do
  begin
    Sleep(1000);
  end;

  {write in TChatConnection.Execute;
   after connection to host}
  isNew := ReadIsNewContact(aSocket);

  if isNew then
  begin
    newContact := TChatContact.Create(self, aSocket);
    Contacts.Add(newContact);
  end
  else
  begin
    { reconnect }
    { TODO : дополнительные тормозящие дидос проверки приделать }
    try
      //read modulus of public key as id
      contactMod := CheckRSAReadString(aSocket, self.Key);
    except
      ProgramLogError('Read string from rsa socket exception');
      CloseSocket(aSocket);
      Exit;
    end;

    for I := 0 to Contacts.Count - 1 do
    begin
      if Contacts.Items[I].ContactRSAKey.PublicKey.ModulusAsString =
        contactMod then
      begin
        if Contacts.Items[I].Accepted then
        begin
          ProgramLogInfo('Sock ' + IntToStr(aSocket) +
            ' reconnect to contact (' +
            Contacts.Items[I].ContactRSAKey.Name + ')');
          Contacts.Items[I].AcceptToReconnect(aSocket);
          exit;
        end;
      end;
    end;
    //if not find - close
    CloseSocket(aSocket);
  end;

end;

procedure TChatUser.Pause;
begin
  { TODO : как то приостановить работу коннектионов в контактах }
  if not FPause then
  begin
    FPause := True;
    FContacts.Lock;
  end;
end;

procedure TChatUser.Resume;
begin
  if FPause then
  begin
    FPause := False;
    FContacts.UnLock;
  end;
end;

end.
