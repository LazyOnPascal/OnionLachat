unit ChatServer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  ChatConnectionList,
  ChatAcceptedConnectionList,
  ChatContactList,
  PollList,
  LbRSA;

type

  EChatServerException = class(Exception);

  { TChatServer }

  TChatServer = class(TThread)
  private
    FPort: word;
    FSock: longint;
    FKey: TLbRSA;    //ключ нашего пользователя
    FContacts: TChatContactList;
    FChatConnectionList: TChatConnectionList;
    FChatAcceptedConnectionList: TChatAcceptedConnectionList;
    FPoll: TPollList;

  public
    constructor Create(aPort: word; aKey: TLbRSA; aContacts: TChatContactList);
    destructor Destroy; override;

  protected
    procedure Execute; override;
    procedure FreeIfAssigned;
    procedure CreateConnectionFromContactList;
    procedure OnAccept;

  end;

implementation

uses
  ChatConnection,
  ChatSocketProcedures,
  Sockets,
  PollPart,
  ChatAcceptedConnection;

{ TChatServer }

constructor TChatServer.Create(aPort: word; aKey: TLbRSA;
  aContacts: TChatContactList);
var
  p: TPollPart;
begin
  try
    FPort := aPort;
    FContacts := aContacts;
    FKey := aKey;
    FSock := StartAcceptSocket(aPort);

    FChatConnectionList := TChatConnectionList.Create;
    FChatAcceptedConnectionList := TChatAcceptedConnectionList.Create;
    FPoll := TPollList.Create;
    p := TPollPart.Create(FSock, nil, @OnAccept, nil, nil, nil, nil);
    p.Read := True;
    FPoll.Add(p);

    CreateConnectionFromContactList;

    //create thread
    inherited Create({False = start now}False);
    FreeOnTerminate := False;
    Priority := tpLower;
  except
    FreeIfAssigned;
    raise;
  end;

end;

destructor TChatServer.Destroy;
begin
  FreeIfAssigned;
  CloseSocket(FSock);
  inherited Destroy;
end;

procedure TChatServer.FreeIfAssigned;
begin
  if assigned(FChatConnectionList) then FChatConnectionList.Free;
  if assigned(FChatAcceptedConnectionList) then FChatAcceptedConnectionList.Free;
  if assigned(FPoll) then FPoll.Free;
end;

procedure TChatServer.CreateConnectionFromContactList;
var
  i: integer;
  connection: TChatConnection;
begin
  for I := 0 to FContacts.Count - 1 do
  begin
    connection := TChatConnection.Create(FContacts.Items[I],FKey,FPoll);
    FChatConnectionList.Add(connection);
  end;
end;

procedure TChatServer.OnAccept;
var
  ClientSock: longint;
begin
  repeat
    ClientSock := fpAccept(FSock, nil, nil);
    if not (ClientSock = -1) then
    begin
      SetNonBlockSocket(ClientSock);
      FChatAcceptedConnectionList.Add(
        TChatAcceptedConnection.Create(ClientSock, 10000));
    end;
  until (ClientSock = -1);
end;

procedure TChatServer.Execute;
begin
  while not self.Terminated do
  begin
    //все полученные новые соединения добавляем в Poll
    FChatAcceptedConnectionList.AddNewToPoll(FPoll);
    FChatAcceptedConnectionList.TimeOut;  // проверяем таймауты



    FPoll.BuildAndCall(100);    //вызов poll
  end;
end;

end.
