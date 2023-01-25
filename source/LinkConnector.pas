unit LinkConnector;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  LbRSA,
  ChatTypes,
  PollList,
  PollPart;

const
  SOCKS_CONNECT_TIMEOUT = 15000;

type

  { TLinkConnector }

  // задача этого класса установить соединение через Socks прокси
  // после этого уладить всё и вызвать aOnConnected

  TLinkConnector = class(TThread)
  private
    FLink: string;
    FSock: longint;
    FSocksPort: word;
    FOnConnected: TOnConnected;

  public
    constructor Create(aLink: string; aSocksPort: word;
  aOnConnected: TOnConnected);
    destructor Destroy; override;

  protected
    procedure Execute; override;

  end;

implementation

uses
  ChatSocketProcedures;

{ TLinkConnector }

constructor TLinkConnector.Create(aLink: string; aSocksPort: word;
  aOnConnected: TOnConnected);
begin
  FOnConnected := aOnConnected;
  FSocksPort := aSocksPort;
  FLink := aLink;

  //create thread
  inherited Create({False = start now}False);
  FreeOnTerminate := False;
  Priority := tpLower;
end;

destructor TLinkConnector.Destroy;
begin
  inherited Destroy;
end;

procedure TLinkConnector.Execute;
var
  host: string;
  port: word;
begin
  host := TorHostFromLink(FLink);
  port := TorOnionPortFromLink(FLink);
  repeat
    FSock := ConnectToSocks5Host(host, port, FSocksPort, self, SOCKS_CONNECT_TIMEOUT);
  until (FSock = -1) or not self.Terminated;

  if self.Terminated then exit;

  FOnConnected(FSock);
end;

end.
