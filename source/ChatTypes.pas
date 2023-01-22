unit ChatTypes;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  ChatSocketMessage;

type

  EChatException = class(Exception);
  ESocketException = class(Exception);

  TOnConnected = procedure of object;

  TOnSocketMessage = procedure(aChatSocketMessage: TChatSocketMessage) of object;
  TOnChatSocketClosed = procedure of object;

implementation

end.
