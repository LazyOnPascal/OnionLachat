unit ChatSocket;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  PollList,
  PollPart,
  ChatTypes;

type

  { TChatSocket }

  TChatSocket = class
  private
    FSock: longint;
    FSocketClosed: boolean;
    FPollPart: TPollPart;
    FOnSocketMessage: TOnSocketMessage;
    FOnChatSocketClosed: TOnChatSocketClosed;
    FReadBuffer: array[0..1048576] of byte;  // мегабайт
    FReadBufferPosition : integer;

  public
    constructor Create(aLink: string;
      aOnSocketMessage: TOnSocketMessage;
      aOnChatSocketClosed: TOnChatSocketClosed);

    constructor Create(aSock: longint;
      aOnSocketMessage: TOnSocketMessage;
      aOnChatSocketClosed: TOnChatSocketClosed);

    destructor Destroy; override;

  private
    procedure Init;

    procedure OnReadable;
    procedure OnWritable;
    procedure OnClosed;
    procedure OnError;
    procedure OnUrgent;
    procedure OnInvalid;

    procedure ReadAll;

  public
    procedure setOnInputMessage(aOnSocketMessage: TOnSocketMessage);

  public
    property Sock: longint read FSock;
    property Poll: TPollPart read FPollPart;
    property Closed: boolean read FSocketClosed;

  end;

implementation

uses
  sockets,
  ChatSocketMessage;

{ TChatSocket }

constructor TChatSocket.Create(aLink: string;
  aOnSocketMessage: TOnSocketMessage; aOnChatSocketClosed: TOnChatSocketClosed);
begin
  Init;
end;

constructor TChatSocket.Create(aSock: longint;
      aOnSocketMessage: TOnSocketMessage;
      aOnChatSocketClosed: TOnChatSocketClosed);
begin
  Init;
  FSock := aSock;
  FOnSocketMessage := aOnSocketMessage;
  FOnChatSocketClosed := aOnChatSocketClosed;

  FPollPart := TPollPart.Create(FSock, @OnWritable,
    @OnReadable, @OnClosed, @OnError, @OnUrgent, @OnInvalid);
end;

destructor TChatSocket.Destroy;
begin
  FPollPart.Free;
  CloseSocket(FSock);
  inherited Destroy;
end;

procedure TChatSocket.Init;
begin
  FSocketClosed := false;
  FReadBufferPosition := 0;
end;

procedure TChatSocket.ReadAll;
var
  bytesReaded : integer;
  socketMessage : TChatSocketMessage;
  b : byte;
  i, startIndex : integer;
  isMessage: boolean;
begin
  bytesReaded := 0;
  //читаем все данные до конца буфера или до возврата -1 или 0
  //0 - означает закрытие зокета
  repeat
    bytesReaded := fprecv(FSock, @FReadBuffer[FReadBufferPosition],
      sizeof(FReadBuffer)-FReadBufferPosition, 0);
    if (bytesReaded <> -1) then FReadBufferPosition += bytesReaded;
    if (bytesReaded = 0) then FSocketClosed := true;
  until not (bytesReaded = -1) or (FReadBufferPosition < sizeof(FReadBuffer))
    or (bytesReaded = 0);

  //декодируем все сообщения в буфере
  startIndex := 0;
  repeat
    socketMessage := TChatSocketMessage.Create(FReadBuffer[startIndex], FReadBufferPosition-1);
    isMessage := socketMessage.Decoded or socketMessage.HashError;
    if (isMessage) then  //если сообщение расшифровано
    begin
      startIndex += socketMessage.UsedBytesFromSource;
      if socketMessage.Decoded and not (FOnSocketMessage = nil) then
      begin
        FOnSocketMessage(socketMessage);
      end;
    end;
    socketMessage.Free;
  until (isMessage);

  //стираем из буфера расшифрованнное сообщение, передвигаем оставшиеся данные к началу
  for i := 0 to ((FReadBufferPosition-1) - startIndex) do
  begin
    FReadBuffer[i] := FReadBuffer[startIndex+i+1];
  end;
  FReadBufferPosition := 0;

  if FSocketClosed then OnClosed;
end;

procedure TChatSocket.OnReadable;
begin
  ReadAll;
end;

procedure TChatSocket.OnWritable;
begin

end;

procedure TChatSocket.OnClosed;
begin
  FSocketClosed := true;
  if FOnChatSocketClosed <> nil then FOnChatSocketClosed;
end;

procedure TChatSocket.OnError;
begin

end;

procedure TChatSocket.OnUrgent;
begin

end;

procedure TChatSocket.OnInvalid;
begin

end;

procedure TChatSocket.setOnInputMessage(aOnSocketMessage: TOnSocketMessage);
begin
  FOnSocketMessage := aOnSocketMessage;
  if not (aOnSocketMessage = nil) then FPollPart.Read := True
  else
    FPollPart.Read := False;
end;

end.
