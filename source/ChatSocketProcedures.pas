unit ChatSocketProcedures;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  ChatTypes;

function StartAcceptSocket(aPort: word): longint;
procedure SetNonBlockSocket(FSocket: longint);

implementation

uses
  DateUtils,
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

end.
