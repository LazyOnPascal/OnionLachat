unit test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, ChatUser, ChatContact,
  ChatMessage, ChatContactList, Bridges{the module contains bridge strings on my computer};

const
  //DEFAULT_BRIDGE_1 = 'enter your bridges here';
  //DEFAULT_BRIDGE_2 = 'enter your bridges here';
  CONNECTION_TIMEOUT = 100;
  DEFAULT_USE_BRIDGES = True;
  DEFAULT_ONION_PORT = 9151;
  DEFAULT_SOCKS_PORT = 9252;

type

  { TChatTest }

  TChatTest = class(TTestCase)
  private
    procedure InitUser(aUser: TChatUser; aNeedNewKey: boolean);
    procedure InitTor(aUser: TChatUser; aPrintConsole : boolean);
    procedure WaitContactConnected(aContact: TChatContact);
    procedure SendRandomMessage(aContact: TChatContact);
    procedure WaitMessageSended(aMessage: TChatMessage);
    procedure WaitNewContact(aContacts: TChatContactList;
      aNewIndex: integer);
    procedure WaitNewMessage(aContact: TChatContact;
      aNewIndex: integer);
    procedure PrintAllTextMessage(aName: string;
  aContact: TChatContact);
  published
    procedure TorConnectDirect;
    procedure TorConnectBridge;
    procedure CreateUsersAndSendMessage;
  end;

implementation

uses
  TorLauncher, Forms, LbAsym, LbRandom, ChatFunctions;

procedure TChatTest.InitUser(aUser: TChatUser; aNeedNewKey: boolean);
begin
  AssertFalse(aUser.Name + '.Constructor Error', aUser.Error);

  ProgramLogInfo(aUser.Name + ' init');
  if aNeedNewKey then
  begin
    ProgramLogInfo('GenerateKeyPair');
    aUser.Key.GenerateKeyPair;

  end;

  {start tor and accept thread}
  aUser.Start;

  AssertFalse(aUser.Name + '.Start Error', aUser.Error);

  {check TOR`s output}
  InitTor(aUser, false);

  {check accept thread}
  AssertFalse(aUser.Name + '.server not work',
    aUser.server.Finished);
end;

procedure TChatTest.InitTor(aUser: TChatUser; aPrintConsole : boolean);
var
  vTimer: integer;
begin
  ProgramLogInfo('Init tor in ' + aUser.Name);

  for vTimer := 0 to CONNECTION_TIMEOUT do
  begin
    if not aPrintConsole then aUser.tor.GetNewOutput
    else ProgramLogInfo(aUser.tor.GetNewOutput);
    //

    Sleep(1000);
    if aUser.tor.ready or aUser.tor.error then break;
  end;

  if aUser.tor.error or not aUser.tor.ready then
    Fail(aUser.Name + ' error in tor launcher');

  if (vTimer = CONNECTION_TIMEOUT) then
    Fail(aUser.Name + ' tor timeout');

  ProgramLogInfo('Tor connected in ' + IntToStr(vTimer) + ' sec');

  ProgramLogInfo('Host: ' + aUser.tor.host+', now sleep 100 sec');
  Sleep(10000);
end;

procedure TChatTest.WaitContactConnected(aContact: TChatContact);
var
  vTimer: integer;
begin
  ProgramLogInfo('Wait contact connected');
  for vTimer := 0 to CONNECTION_TIMEOUT do
  begin
    if aContact.Connection.Connected then break
    else
      Sleep(1000);
  end;
  AssertTrue('Contact not connected',
    aContact.Connection.Connected);
  ProgramLogInfo('Contact connected in ' +
    IntToStr(vTimer) + ' sec');
end;

procedure TChatTest.SendRandomMessage(aContact: TChatContact);
var
  messageToSend: TTextMessage;
begin
  messageToSend := TTextMessage.Create(RandomString(10));
  aContact.Messages.Add(messageToSend);
  WaitMessageSended(messageToSend);
end;

procedure TChatTest.WaitMessageSended(aMessage: TChatMessage);
var
  vTimer: integer;
begin
  ProgramLogInfo('Wait message sended');
  for vTimer := 0 to CONNECTION_TIMEOUT do
  begin
    if aMessage.Sended then break
    else
      Sleep(1000);
  end;
  AssertTrue('Message not sended', aMessage.Sended);
  ProgramLogInfo('Message sended in ' +
    IntToStr(vTimer) + ' sec');

end;

procedure TChatTest.WaitNewContact(aContacts: TChatContactList;
  aNewIndex: integer);
var
  vTimer: integer;
begin
  ProgramLogInfo('Wait new contact');
  for vTimer := 0 to CONNECTION_TIMEOUT do
  begin
    if (aContacts.Count >= aNewIndex) then break;
    Sleep(1000);
  end;
  AssertTrue('No new contact', (aContacts.Count >= aNewIndex));
  ProgramLogInfo('New contact in ' + IntToStr(vTimer) + ' sec');

end;

procedure TChatTest.WaitNewMessage(aContact: TChatContact; aNewIndex: integer);
var
  vTimer: integer;
begin
  ProgramLogInfo('Wait new message');
  for vTimer := 0 to CONNECTION_TIMEOUT do
  begin
    if (aContact.Messages.Count >= aNewIndex) then break;
    Sleep(1000);
  end;
  AssertTrue('No new message', (aContact.Messages.Count >=
    aNewIndex));
  ProgramLogInfo('New message in ' + IntToStr(vTimer) + ' sec');
end;

procedure TChatTest.PrintAllTextMessage(aName: string; aContact: TChatContact);
var
  direction: string;
  mes: TTextMessage;
  i: integer;
begin
  ProgramLogInfo('-BEGIN- all text messages in ' + aName);
  for i := 0 to aContact.Messages.Count - 1 do
  begin
    if aContact.Messages.Items[i] is TTextMessage then
    begin
      mes := TTextMessage(aContact.Messages.Items[i]);
      if mes.Direction = MD_Outgoing then direction := ' Outgoing: ';
      if mes.Direction = MD_Incoming then direction := ' Incoming: ';
      WriteLn('Index ' + IntToStr(i) + direction + mes.Text);
    end;
  end;
  WriteLn('-END-');
end;

procedure TChatTest.TorConnectDirect;
var
  tor: TTorLauncher;
  vTimer: byte;
begin
  tor := TTorLauncher.Create('', 'torconfigs/ConnectDirectConfig',
    9151, 9152, TtorBridges.Create('', '', ''));
  try
    tor.Execute;
    for vTimer := 0 to CONNECTION_TIMEOUT do
    begin
      Write(tor.GetNewOutput);
      Sleep(1000);
      if tor.ready or tor.error then break;
    end;
    AssertTrue('Tor not connected!', tor.ready);
  finally
    tor.Free;
  end;

end;

procedure TChatTest.TorConnectBridge;
var
  tor: TTorLauncher;
  vTimer: byte;
begin
  tor := TTorLauncher.Create('', 'torconfigs/ConnectBridgeConfig',
    9151, 9152, TtorBridges.Create(DEFAULT_BRIDGE_1, DEFAULT_BRIDGE_2, ''));
  try
    tor.Execute;
    for vTimer := 0 to CONNECTION_TIMEOUT do
    begin
      Write(tor.GetNewOutput);
      Sleep(1000);
      if tor.ready or tor.error then break;
    end;
    AssertTrue('Tor not connected!', tor.ready);
  finally
    tor.Free;
  end;
end;

procedure TChatTest.CreateUsersAndSendMessage;
var
  user1, user2: TChatUser;
  vLink: string;
  user1ToUser2Contact, user2ToUser1Contact: TChatContact;
  memstream, memstream2: TMemoryStream;
  bridge1, bridge2: TTorBridges;
begin
  Writeln(' ');
  ProgramLogInfo('---Test 1 begin---, CreateTwoUserAndSendMessage');

  memstream := TMemoryStream.Create;
  memstream2 := TMemoryStream.Create;

  try
    {create new users}
    if DEFAULT_USE_BRIDGES then
    begin
      bridge1 := TTorBridges.Create(DEFAULT_BRIDGE_1, DEFAULT_BRIDGE_2, '');
      bridge2 := TTorBridges.Create(DEFAULT_BRIDGE_1, DEFAULT_BRIDGE_2, '');
    end
    else
    begin
      bridge1 := TTorBridges.Create('', '', '');
      bridge2 := TTorBridges.Create('', '', '');
    end;

    user1 := TChatUser.Create('User1', '', 'torconfigs/User1',
      DEFAULT_ONION_PORT{aServerPort}, DEFAULT_SOCKS_PORT{aSocksPort},
      aks128, bridge1);
    user2 := TChatUser.Create('User2', '', 'torconfigs/User2',
      DEFAULT_ONION_PORT + 100, DEFAULT_SOCKS_PORT + 100, aks128, bridge2);

    InitUser(user1, True);
    InitUser(user2, True);

    {get link}
    vLink := user1.getLink;

    {connect}
    ProgramLogInfo('Create user2ToUser1Contact');
    user2ToUser1Contact := TChatContact.Create(user2, vLink);
    user2.Contacts.Add(user2ToUser1Contact);
    //wait
    WaitContactConnected(user2ToUser1Contact);

    {send message}
    SendRandomMessage(user2ToUser1Contact);

    {recive message}
    //wait contact
    WaitNewContact(user1.Contacts, 1);
    user1ToUser2Contact := user1.Contacts.Items[0];
    SendRandomMessage(user1ToUser2Contact);
    //wait message
    WaitNewMessage(user1ToUser2Contact, 1);

    //get message
    PrintAllTextMessage('User1toUser2', user1ToUser2Contact);
    PrintAllTextMessage('User2toUser1', user2ToUser1Contact);

    //reconnect
    ProgramLogInfo('---Test 2 begin---, CheckReconnect');
    ProgramLogInfo('User1 tor restart');
    user1.Tor.Restart;
    Sleep(2000);
    InitTor(user1, false);

    //AssertFalse('User2 after disconnect still report Connected',
    //  user2ToUser1Contact.Connection.Connected);

    ProgramLogInfo('User2 try reconnect');
    user2ToUser1Contact.Reconnect;
    WaitContactConnected(user2ToUser1Contact);


    AssertTrue('user2ToUser1Contact not connected',
      user2ToUser1Contact.Connection.Connected);
    AssertTrue('user1ToUser2Contact not connected',
      user1ToUser2Contact.Connection.Connected);


    //send message again
    SendRandomMessage(user1ToUser2Contact);
    SendRandomMessage(user2ToUser1Contact);

    PrintAllTextMessage('User1toUser2', user1ToUser2Contact);
    PrintAllTextMessage('User2toUser1', user2ToUser1Contact);

    //save to stream
    ProgramLogInfo('---Test 3---, read from stream');

    ProgramLogInfo('Pause and pack');
    user1.Pause;
    user1.PackToStream(memstream);
    user1.Resume;
    user1.Free;
    Sleep(1000);

    {user2.Pause;
    user2.PackToStream(memstream2);
    user2.Resume;
    user2.Free;

    ProgramLogInfo('User2 restore from stream');
    memstream2.Position := 0;
    user2 := TChatUser.LoadFromStream(memstream2);
    InitUser(user2, False); }

    //or just restart tor, if this is not done,
    //the port of user1 will be "alredy in use"
    user2.Tor.Restart;
    initTor(user2, false);


    //load
    ProgramLogInfo('User1 restore from stream');
    memstream.Position := 0;
    user1 := TChatUser.LoadFromStream(memstream);
    InitUser(user1, False);


    //user2 restore connection
    ProgramLogInfo('User2 try reconnect');
    user2ToUser1Contact := user2.Contacts.Items[0];
    user2ToUser1Contact.Reconnect;
    WaitContactConnected(user2ToUser1Contact);

    user1ToUser2Contact := user1.Contacts.Items[0];

    //send message again
    SendRandomMessage(user1ToUser2Contact);
    SendRandomMessage(user2ToUser1Contact);

    PrintAllTextMessage('User1toUser2', user1ToUser2Contact);
    PrintAllTextMessage('User2toUser1', user2ToUser1Contact);

    ProgramLogInfo('Disconnect user1ToUser2Contact');
    user1ToUser2Contact.Connection.Terminate;
    Sleep(1000);

    ProgramLogInfo('--END OF TEST--');


  finally

    {free memory}
    WriteLn('free memory');
    user1.Free;
    user2.Free;
    memstream.Free;
    memstream2.Free;
  end;

end;



initialization

  RegisterTest(TChatTest);
end.
