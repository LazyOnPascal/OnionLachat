unit ChatTestCase;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  fpcunit,
  testregistry,
  TorLauncher;

const
  BRIDGE_1 = '';
  BRIDGE_2 = '';
  CONNECTION_TIMEOUT = 100;
  TOR_HOST_PORT_1 = 9251;
  TOR_HOST_PORT_2 = 9253;
  SERVER_PORT_1 = 9254;
  SERVER_PORT_2 = 9255;

type

  { TChatTest }

  TChatTest = class(TTestCase)
  private
    procedure InitTor(aTor: TTorLauncher; aPrintConsole: boolean);
  published
    procedure InitTor;
    procedure TestServer;
    procedure FreeTor;
  end;

implementation

uses
  ChatLog,
  ChatServer,
  ChatTypes,
  ChatContactList,
  ChatContact,
  LbRSA,
  LbAsym;

var
  tor: TTorLauncher = nil;
  tor2: TTorLauncher = nil;
  server: TChatServer = nil;

procedure TChatTest.TestServer;
var
  contacts: TChatContactList;
  contact: TChatContact;
  key: TLbRSA;
begin
  if not assigned(tor) or not assigned(tor) then
    Fail('Tor not ready for server test');
  try
    try
      key := TLbRSA.Create(nil, 'RSA key name', aks128);
      contacts := TChatContactList.Create;
      contact := TChatContact.Create('Contact1', tor.Host);
      contacts.Add(contact);
      contact := TChatContact.Create('Contact2', tor2.Host);
      contacts.Add(contact);
      contact := TChatContact.Create('Contact3', 'onion.site3');
      contacts.Add(contact);
      server := TChatServer.Create(SERVER_PORT_1, key, contacts);
    finally
      if assigned(server) then server.Free;
      if assigned(contacts) then contacts.Free;
    end;
  except
    on E: EChatException do
    begin
      Fail('Server error, message - ' + E.Message);
    end;
  end;
end;

procedure TChatTest.FreeTor;
begin
  tor.Free;
  tor2.Free;
end;

procedure TChatTest.InitTor(aTor: TTorLauncher; aPrintConsole: boolean);
var
  vTimer: integer;
begin
  ProgramLogDebug('Init tor');

  for vTimer := 0 to CONNECTION_TIMEOUT do
  begin
    if not aPrintConsole then aTor.GetNewOutput
    else
      ProgramLogDebug(aTor.GetNewOutput);
    Sleep(1000);
    if aTor.ready or aTor.error then break;
  end;

  if aTor.error then
    Fail('Error in tor launcher');

  if not (aTor.ready) then
    Fail('Tor timeout');

  ProgramLogInfo('Tor connected in ' + IntToStr(vTimer) + ' sec');
  ProgramLogDebug('Host: ' + aTor.host);
end;

procedure TChatTest.InitTor;
begin
  tor := TTorLauncher.Create('', 'torconfigs/Tor1', TOR_HOST_PORT_1,
    SERVER_PORT_1, TTorBridges.Create(BRIDGE_1, BRIDGE_2, ''));
  tor2 := TTorLauncher.Create('', 'torconfigs/Tor2', TOR_HOST_PORT_2,
    SERVER_PORT_2, TTorBridges.Create(BRIDGE_1, BRIDGE_2, ''));
  InitTor(tor, True);
  InitTor(tor2, True);
end;

initialization

  RegisterTest(TChatTest);
end.
