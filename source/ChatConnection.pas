unit ChatConnection;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  ChatContact,
  ChatSocket,
  ChatSocketMessage,
  LinkConnector,
  LbRSA,
  PollList;

type

  { TChatConnection }

  TChatConnection = class
  private
    FContact: TChatContact;    // link to user contact
    FPollList: TPollList;      // link to server poll list
    FSessionKey: string;
    FLinkConnector: TLinkConnector;
    FInputSocket: TChatSocket;
    FOutputSocket: TChatSocket;

  public
    constructor Create(aContact: TChatContact; aSocksPort: word;
      aUserKey: TLbRSA; aPollList: TPollList);
    destructor Destroy; override;
  private
    procedure OnMessage(aChatSocketMessage: TChatSocketMessage);
    procedure OnClosed;
    procedure OnConnected(aSocket:longint);
  end;

implementation

{ TChatConnection }

constructor TChatConnection.Create(aContact: TChatContact; aSocksPort: word;
  aUserKey: TLbRSA; aPollList: TPollList);
begin
  FContact := aContact;
  FPollList := aPollList;
  FLinkConnector := TLinkConnector.Create(FContact.Link, aSocksPort, @OnConnected);
end;

destructor TChatConnection.Destroy;
begin
  if assigned(FLinkConnector) and not FLinkConnector.Finished then
  begin
    FLinkConnector.Terminate;
    while not FLinkConnector.Finished do Sleep(1);
  end;
  if assigned(FLinkConnector) then FreeAndNil(FLinkConnector);

  inherited Destroy;
end;

procedure TChatConnection.OnMessage(aChatSocketMessage: TChatSocketMessage);
begin

end;

procedure TChatConnection.OnClosed;
begin

end;

procedure TChatConnection.OnConnected(aSocket:longint);
begin
  // FLinkConnector вызовет это место если соединение socks5 установлено
end;

end.
