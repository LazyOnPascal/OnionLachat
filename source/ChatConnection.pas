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
    constructor Create(aContact: TChatContact; aUserKey: TLbRSA;
      aPollList: TPollList);
    destructor Destroy; override;
  private
    procedure OnMessage(aChatSocketMessage: TChatSocketMessage);
    procedure OnClosed;
    procedure OnConnected;
  end;

implementation

{ TChatConnection }

constructor TChatConnection.Create(aContact: TChatContact; aUserKey: TLbRSA;
  aPollList: TPollList);
begin
  FContact := aContact;
  FPollList := aPollList;
  FLinkConnector := TLinkConnector.Create(FContact.Link, FContact.Key,
    aUserKey, FPollList, @OnConnected);
end;

destructor TChatConnection.Destroy;
begin
  inherited Destroy;
end;

procedure TChatConnection.OnMessage(aChatSocketMessage: TChatSocketMessage);
begin

end;

procedure TChatConnection.OnClosed;
begin

end;

procedure TChatConnection.OnConnected;
begin
  // FLinkConnector вызовет это место если соединение полностью установлено
end;

end.
