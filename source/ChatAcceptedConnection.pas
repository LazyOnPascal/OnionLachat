unit ChatAcceptedConnection;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  ChatSocket,
  PollList,
  ChatSocketMessage;

type

  { TChatAcceptedConnection }

  TChatAcceptedConnection = class
  private
    FIsNew: boolean;
    FChatSocket : TChatSocket;
    FStartTime: TDateTime;
    FLastAction: TDateTime;
    FTimeOut: longint;

  public
    constructor Create(aSock: longint; aTimeOut: longint);
    destructor Destroy; override;
  private
    procedure OnMessage(aChatSocketMessage:TChatSocketMessage);
    procedure OnClosed;
  public
    function IsTimeOut : boolean;
  public
    property ChatSocket: TChatSocket read FChatSocket;
    property New: boolean read FIsNew write FIsNew;

  end;

implementation

uses
  PollPart;

{ TChatAcceptedConnection }

constructor TChatAcceptedConnection.Create(aSock: longint; aTimeOut: longint);
begin
  FChatSocket := TChatSocket.Create(aSock,@self.OnMessage,@self.OnClosed);
  FStartTime := Now;
  FLastAction := Now;
  FTimeOut := aTimeOut div 1000;
  FIsNew := true;
end;

destructor TChatAcceptedConnection.Destroy;
begin
  FChatSocket.Free;
  inherited Destroy;
end;

procedure TChatAcceptedConnection.OnMessage(
  aChatSocketMessage: TChatSocketMessage);
begin
  FLastAction := Now;
  // принять сообщение
end;

procedure TChatAcceptedConnection.OnClosed;
begin
  //зокет закрылся
end;

function TChatAcceptedConnection.IsTimeOut : boolean;
var
  TimeElapsed:TDateTime;
begin
  Result := false;
  TimeElapsed := Now - FLastAction;
  if (StrToInt(FormatDateTime('ss',TimeElapsed)) > FTimeOut) then
  begin
    Result := true;
  end;
end;


end.

