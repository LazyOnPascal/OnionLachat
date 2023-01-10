unit GUI;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ChatUser, LbAsym, TorLauncher,
  GUIContacts, Forms, ExtCtrls, StdCtrls;

type

  { GUIMaster }

  { TGUIMaster }

  TGUIMaster = class
  private
  const
    {$ifdef Win64}
       DATABASE_NAME = 'databasewin.chat';
    {$endif}
    {$ifdef Unix}
       DATABASE_NAME = 'database.chat';
    {$endif}
    DATABASE_TEST_STRING = '|3xpo}[axzx5vx<z';
  var
    FUser: TChatUser;
    FPassword: string;
    FNeedConnect: boolean;
    FAutoConnect: boolean;
    FGUIContacts: TGUIContactList;

  public
    constructor Create;
    destructor Destroy; override;
  public
    procedure SaveData;
    function LoadData(aPassword: string): boolean;
    procedure NewUser(aName: string; aKeySize: TLbAsymKeySize;
      aHostPort, aSocksPort: word; aTorBinDir, aTorConfigDir: string;
      aBridges: TTorBridges);
    function DataBaseExists: boolean;
    procedure Connect;
    procedure UpdateTorStatus;
    procedure NewContact;
    procedure UpdateContactsAndMessages;
    procedure GetLink;
    procedure ReconnectConntact;
    procedure ContactInfo;
    procedure UpdateContactList;


  public
    property user: TChatUser read FUser;
    property pass: string read FPassword write FPassword;
    property autostart: boolean read FAutoConnect write FAutoConnect;
    property contacts: TGUIContactList read FGUIContacts;

  end;

var
  gm: TGUIMaster;

implementation

uses
  ChatProtocol, Main, Dialogs, ChatContact,
  Clipbrd, ChatConnection, LbString;

{ GUIMaster }

constructor TGUIMaster.Create;
begin
  inherited Create;
  FUser := nil;
  FNeedConnect := False;
  FAutoConnect := FAutoConnect;
  FGUIContacts := TGUIContactList.Create();
end;

destructor TGUIMaster.Destroy;
begin
  if assigned(FUser) then FUser.Free;
  FGUIContacts.Free;
  inherited Destroy;
end;

procedure TGUIMaster.SaveData;
var
  filestr: TFileStream;
  Source, dest: TMemoryStream;
  PrintStr: TMemoryStream;
  st: string;
  i: integer;
begin

  try

    if not assigned(FUser) or FUser.Error then Exit;

    Source := TMemoryStream.Create;
    dest := TMemoryStream.Create;
    try
      filestr := TFileStream.Create(DATABASE_NAME, fmCreate);
      Source.WriteAnsiString(DATABASE_TEST_STRING);
      Source.WriteByte(byte(FAutoConnect));
      FUser.PackToStream(Source);
      Source.Position := 0;
      EncriptStream(Source, dest, self.pass);
      dest.Position := 0;
      filestr.CopyFrom(dest, dest.Size);
    finally
      Source.Free;
      dest.Free;
      filestr.Free;
      //PrintStr.Free;
    end;

  except

    { TODO : написать ошибки записи базы}

  end;

end;

function TGUIMaster.LoadData(aPassword: string): boolean;
var
  filestr: TFileStream;
  Source, dest: TMemoryStream;
  PrintStr: TMemoryStream;
  st: string;
  i: integer;
begin

  Result := False;

  try
    Source := TMemoryStream.Create;
    dest := TMemoryStream.Create;
    try
      filestr := TFileStream.Create(DATABASE_NAME, fmOpenRead or
        fmShareDenyWrite);
      Source.CopyFrom(filestr, filestr.Size);
      Source.Position := 0;
      {
       // first print stream from file
       PrintStr := TMemoryStream.Create;
       Source.Position := 0;
       LbEncodeBase64(Source, PrintStr);
       Source.Position := 0;
       st := '';
       PrintStr.Position := 0;
       for i := 0 to (PrintStr.Size - 1) do
       begin
         st += char(PrintStr.ReadByte);
       end;
       WriteLn(' --- Source Data from file readed ----- ');
       Writeln(st);
       WriteLn(' -------------------------------------- ');
      }


      DecriptStream(Source, dest, aPassword);
      dest.Position := 0;
      {
       // second print encripted
       PrintStr.Clear;
       dest.Position := 0;
       LbEncodeBase64(dest, PrintStr);
       dest.Position := 0;
       st := '';
       PrintStr.Position := 0;
       for i := 0 to (PrintStr.Size - 1) do
       begin
         st += char(PrintStr.ReadByte);
       end;
       WriteLn(' --- Decripted Data from file --------- ');
       Writeln(st);
       WriteLn(' -------------------------------------- ');
      }


      try
        if not (dest.ReadAnsiString = DATABASE_TEST_STRING) then
          exit;
        FAutoConnect := boolean(dest.ReadByte);
        FUser := TChatUser.LoadFromStream(dest);
        if assigned(FUser) and not FUser.Error then
        begin
          self.pass := aPassword;
          Result := True;
        end;
      except
      end;
    finally
      Source.Free;
      dest.Free;
      filestr.Free;
    end;

  except

    { TODO : написать ошибки открытия базы}

  end;

end;

procedure TGUIMaster.NewUser(aName: string; aKeySize: TLbAsymKeySize;
  aHostPort, aSocksPort: word; aTorBinDir, aTorConfigDir: string; aBridges: TTorBridges);
begin
  if assigned(FUser) then FUser.Free;
  FUser := TChatUser.Create(aName, aTorBinDir, ExtractFilePath(Application.ExeName) +
    aTorConfigDir, aHostPort, aSocksPort, aKeySize, aBridges);
  FUser.Key.GenerateKeyPair;
  FNeedConnect := False;
end;


function TGUIMaster.DataBaseExists: boolean;
begin
  Result := FileExists(DATABASE_NAME);
end;

procedure TGUIMaster.Connect;
begin
  if FUser.Error then Exit;
  FUser.Start;
  FNeedConnect := True;
end;

procedure TGUIMaster.UpdateTorStatus;
begin
  if not assigned(FUser) or FUser.Error then Exit;
  if (FNeedConnect or FAutoConnect) and assigned(FUser.tor) and not
    FUser.tor.error then
  begin
    FUser.tor.GetNewOutput;
  end;
end;

procedure TGUIMaster.NewContact;
var
  link: string;
  contact: TChatContact;
begin
  link := '';
  if InputQuery('New contact', 'Enter link', link) then
  begin
    contact := TChatContact.Create(FUser, link);
    if (FUser.Contacts.Add(contact) = -1) then
    begin
      ShowMessage('Error'
        );
      contact.Free;
    end;
  end;
end;

procedure TGUIMaster.UpdateContactsAndMessages;
var
  i: integer;
  strInList: string;
  conn: TChatContact;
begin
  self.FGUIContacts.Update;
  {for i := 0 to FUser.Contacts.Count - 1 do
  begin
    conn := Fuser.Contacts.Items[i];
    strInList := conn.ContactRSAKey.Name;
    if conn.Connection.Connected then
    begin
      strInList += ' ONLINE';
    end
    else
    begin
      strInList += ' OFFLINE';
    end;

    {if (fChat.lbContacts.Count >= (i + 1)) then
      fChat.lbContacts.Items[i] := strInList
    else
      fChat.lbContacts.Items.Add(strInList); }

  end;}
end;

procedure TGUIMaster.GetLink;
begin
  if not assigned(FUser) or FUser.Error or not FUser.Tor.ready then
    exit;
  Clipboard.AsText := gm.user.getLink;
  ShowMessage('Link has been copied to the clipboard');
end;

procedure TGUIMaster.ReconnectConntact;
begin
  if not assigned(FUser) or FUser.Error or not FUser.Tor.ready then
    exit;
  FUser.Contacts.CheckForReconnect;
end;

procedure TGUIMaster.ContactInfo;
begin
  if assigned(FGUIContacts.ActiveMessagesList) then
  begin
    //открыть инфомацию о выделенном контакте
    //FGUIContacts.ActiveMessagesList.ChatContact;
    ShowMessage('WOw');
  end;
end;

procedure TGUIMaster.UpdateContactList;
begin
  FGUIContacts.Rebuild;
end;

end.
