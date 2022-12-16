unit ChatLocalServer;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Sockets, BaseUnix, TorLauncher;

type

  EChatServerException = class(Exception);

  { TChatServer }

  TChatServer = class(TThread)
  private
    FSocket: longint;
    FLocalPort: word;
    FUser: TObject;

  public
    constructor Create(aPort: word; aUser: TObject);
    constructor LoadFromStream(aStream:TStream; aUser: TObject);
    destructor Destroy; override;
  public
    procedure StartOfSockService;
    procedure PackToStream(aStream:TStream);

  private
    procedure CheckNewAcceptedConnections;

  protected
    procedure Execute; override;
  end;

implementation

uses DateUtils, ChatFunctions, ChatUser;

{ TChatServer }

constructor TChatServer.Create(aPort: word; aUser: TObject);
  {UI thread}
begin
  FLocalPort := aPort;
  FUser := aUser;

  inherited Create({False = start now}True);
  FreeOnTerminate := False;
  Priority := tpLower;
end;

constructor TChatServer.LoadFromStream(aStream: TStream; aUser: TObject);
begin
  self.Create(word(aStream.ReadDWord), aUser);;
end;

procedure TChatServer.PackToStream(aStream: TStream);
begin
  aStream.WriteDWord(FLocalPort);
end;

destructor TChatServer.Destroy;
  {UI thread}
var
  answ : longint;
begin
  answ := CloseSocket(FSocket);
  ProgramLogInfo('Accept thread sock ' + IntToStr(
      FSocket) + ' closed with answer ' + IntToStr(answ));
  inherited Destroy;
end;

procedure TChatServer.Execute;
{server thread}
begin
  ProgramLogInfo('Accept thread sock ' + IntToStr(FSocket)+' start');
  while not self.Terminated do
  begin
    CheckNewAcceptedConnections;
    Sleep(100);
  end;
end;

procedure TChatServer.CheckNewAcceptedConnections;
{server thread}
var
  ClientSock: longint;
begin
  repeat
    ClientSock := fpAccept(FSocket, nil, nil);
    if not (ClientSock = -1) then
    begin
      TChatUser(FUser).AcceptedNewSocked(ClientSock);
    end;
  until (ClientSock = -1);
end;

procedure TChatServer.StartOfSockService;
{UI thread}
var
  SockAddr: TInetSockAddr;
begin

  FSocket := fpSocket(AF_INET, SOCK_STREAM, IPPROTO_IP);
  FpFcntl(FSocket, F_SetFl, O_NONBLOCK);
  if FSocket = -1 then
  begin
    raise EChatServerException.Create('fpSocket FAILED');
  end;

  with SockAddr do
  begin
    sin_family := AF_INET;
    sin_port := htons(FLocalPort);
    sin_addr := StrToNetAddr('127.0.0.1');
  end;

  if fpBind(FSocket, @SockAddr, sizeof(SockAddr)) = -1 then
  begin
    case SocketError of
      ESockEBADF: ProgramLogInfo('The socket descriptor is invalid.');
      ESockEINVAL: ProgramLogInfo(
          'The socket is already bound to an address,');
      ESockEACCESS: ProgramLogInfo(
          'Address is protected and you dont have permission to open it.');
      EsockADDRINUSE: ProgramLogInfo('Port(' + IntToStr(
          FLocalPort) + ') alredy in use');
      else
        ProgramLogInfo('SocketError code ' + IntToStr(SocketError));
    end;
    raise EChatServerException.Create('fpBind FAILED');
  end;

  if fpListen(FSocket, 512) = -1 then
  begin
    raise EChatServerException.Create('fpListen FAILED');
  end;

end;



end.
