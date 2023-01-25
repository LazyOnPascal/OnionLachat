unit ChatSocketProcedures;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  ChatTypes;

function StartAcceptSocket(aPort: word): longint;
procedure SetNonBlockSocket(FSocket: longint);
function ConnectToSocks5Host(aHost: string; aHostPort, aSocksPort: word;
  aThread: TThread; aTimeOut: longint): longint;
function recvTimeOut(aSock: longint; aBuf: pointer; aLength: longint;
  aFlags: longint; aTimeOut: longint; aThread: TThread): int64;
procedure SetBlockSocket(FSocket: longint);
function TorHostFromLink(aLink: string): string;
function TorOnionPortFromLink(aLink: string): word;

implementation

uses
  DateUtils,
  ChatConst,
  Sockets
  {$ifdef Unix}, BaseUnix {$endif};

function StartAcceptSocket(aPort: word): longint;
var
  SockAddr: TInetSockAddr;
  error: string;
begin
  error := '';
  Result := -1;

  try

    Result := fpSocket(AF_INET, SOCK_STREAM, IPPROTO_IP);

    if Result = -1 then
    begin
      raise ESocketException.Create('fpSocket ruturn -1');
    end;

    SetNonBlockSocket(Result);

    with SockAddr do
    begin
      sin_family := AF_INET;
      sin_port := htons(aPort);
      sin_addr := StrToNetAddr('127.0.0.1');
    end;

    if fpBind(Result, @SockAddr, sizeof(SockAddr)) = -1 then
    begin
      case SocketError of
        ESockEBADF: error := 'the socket descriptor is invalid.';
        ESockEINVAL: error :=
            'the socket is already bound to an address';
        ESockEACCESS: error :=
            'address is protected and you dont have permission to open it.';
        EsockADDRINUSE: error :=
            'port(' + IntToStr(aPort) + ') alredy in use';
        else
          error := 'SocketError code ' + IntToStr(SocketError);
      end;
      raise ESocketException.Create('fpBind FAILED, ' + error);
    end;

    if fpListen(Result, 512) = -1 then
    begin
      raise ESocketException.Create('fpListen FAILED');
    end;
  except
    on E: ESocketException do
    begin
      if not (Result = -1) then CloseSocket(Result);
      raise EChatException.Create('start of accept socket on port ' +
        IntToStr(aPort) + ' FAILED, message - ' + E.Message);
    end
    else
    begin
      raise;
    end;
  end;

end;

procedure SetNonBlockSocket(FSocket: longint);
{$ifdef Win64}
var
  Mode : longint = 1;
{$endif}
begin
  {$ifdef Unix}
    FpFcntl(FSocket, F_SetFl, O_NONBLOCK);
  {$endif}
  {$ifdef Win64}
    ioctlsocket(FSocket, FIONBIO, @Mode);
  {$endif}
end;

function ConnectToSocks5Host(aHost: string; aHostPort, aSocksPort: word;
  aThread: TThread; aTimeOut: longint): longint;
var
  SAddr: TInetSockAddr;
  Buffer: array[0..1024] of byte;
  x: integer;
  s: longint;
begin

  Result := -1;
  s := fpSocket(AF_INET, SOCK_STREAM, IPPROTO_IP);

  if s = -1 then exit;


  with SAddr do
  begin
    sin_family := AF_INET;
    sin_port := htons(aSocksPort);
    sin_addr := StrToNetAddr('127.0.0.1');
  end;

  if fpconnect(s, @SAddr, sizeof(SAddr)) = -1 then
  begin
    Result := -1;
    CloseSocket(s);
    exit;
  end;

  //connect
  Buffer[0] := 5;//BYTE Version = 5
  Buffer[1] := 1;//BYTE nMethods = 1
  Buffer[2] := 0;//BYTE methods[nMethods] = 0
  fpsend(s, @Buffer[0], 3, 0);
  Buffer[0] := 99;
  Buffer[1] := 99;

  //answer
  //BYTE Version = 5
  //BYTE method = 0
  if not (recvTimeOut(s, @Buffer[0], 2, 0, aTimeOut, aThread) = 2) then
  begin
    Result := -1;
    CloseSocket(s);
    exit;
  end;

  if not (Buffer[0] = 5) or not (Buffer[1] = 0) then
  begin
    Result := -1;
    CloseSocket(s);
    exit;
  end;

  //command connect
  Buffer[0] := 5;//BYTE Version = 5
  Buffer[1] := 1;//BYTE Cmd = 1 - CONNECT
  Buffer[2] := 0;//BYTE Reserved = 0
  Buffer[3] := 3;//BYTE AType = 3 - domain name
  Buffer[4] := Length(aHost);//BYTE addrLength
  for x := 1 to Length(aHost) do
  begin
    Buffer[x + 4] := byte(aHost[x]);
  end;
  Buffer[5 + Length(aHost)] := aHostPort shr 8; //WORD htons(port)
  Buffer[6 + Length(aHost)] := byte(aHostPort);

  fpsend(s, @Buffer[0], 7 + Length(aHost), 0);
  Buffer[0] := 99;
  Buffer[1] := 99;


  //answer 2
  //BYTE Version = 5
  //BYTE Rep = 0 - Ok
  //.......
  if not (recvTimeOut(s, @Buffer[0], 10, 0, aTimeOut, aThread) = 10) then
  begin
    Result := -1;
    CloseSocket(s);
    exit;
  end;

  if not (Buffer[0] = 5) or not (Buffer[1] = 0) then
  begin
    Result := -1;
    CloseSocket(s);
    exit;
  end;

  Result := s;

end;

function recvTimeOut(aSock: longint; aBuf: pointer; aLength: longint;
  aFlags: longint; aTimeOut: longint; aThread: TThread): int64;
var
  workTime: integer;
  def_flags: longint;
  vBuf: pointer;
  vLen: longint;
  vRes: integer;
begin

  workTime := 0;
  Result := 0;

  SetNonBlockSocket(aSock);
  try

    vBuf := aBuf;
    vLen := aLength;
    vRes := -1;

    while (workTime < aTimeOut) and not aThread.CheckTerminated do
    begin
      vRes := fprecv(aSock, vBuf, vLen, aFlags);
      if (vRes = 0) then
      begin
        break;
      end
      else if (vRes > 0) then
      begin
        Result += vRes;
        vLen -= vRes;
        vBuf := Pointer(vBuf + vRes);
      end;
      if Result = aLength then
        break;

      Sleep(100);
      workTime += 100;
    end;

  finally
    SetBlockSocket(aSock);
  end;

end;

procedure SetBlockSocket(FSocket: longint);
{$ifdef Win64}
var
  Mode : longint = 0;
{$endif}
begin
  {$ifdef Unix}
    FpFcntl(FSocket, F_SetFl, 0);
  {$endif}
  {$ifdef Win64}
    ioctlsocket(FSocket, FIONBIO, @Mode);
  {$endif}
end;

function TorHostFromLink(aLink: string): string;
var
  vTempLink: string;
  vPos: integer;
begin
  vPos := Pos(':', aLink);
  if vPos > 0 then
  begin
    vTempLink := Copy(aLink, 0, vPos - 1);
  end
  else
  begin
    vTempLink := aLink;
  end;
  Result := vTempLink + '.onion';
end;

function TorOnionPortFromLink(aLink: string): word;
var
  vPos: integer;
begin
  vPos := Pos(':', aLink);
  if vPos > 0 then
  begin
    Result := StrToInt(Copy(aLink, vPos + 1, 8));
  end
  else
  begin
    Result := DEFAULT_ONION_PORT;
  end;
end;

end.
