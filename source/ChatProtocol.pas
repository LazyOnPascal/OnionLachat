unit ChatProtocol;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Unix, LbRSA, ChatContact, ChatMessage,
  ChatMessageList, ChatConnection;

type
  EChatNet = class(Exception);

type
  TTranferType = (TTNON = 0, TTPublicKey, TTSessionKey,
    TTSessionKeyVeryfi, TTPresenseMessages, TTSendOnionLink,
    TTIsNewContact, TTIsOldContact, TTCheckRSA);

const
  PROTOCOL_VERSION_TRANSFERS = 2;{TTranferType and TMessageCode}
  SESSION_KEY_SIZE = 32;
  DEFAULT_ONION_PORT = 9055;
  DEFAULT_SOCKS_PORT = 9065;
  IO_SOCKET_TIMEOUT = 50000;

{read|write to socket}
function recvTimeOut(s: cint; buf: pointer; len: size_t;
  flags: cint; aTimeOut: integer; thread : TChatConnection): ssize_t;
function sendTimeOut(s: cint; msg: pointer; len: size_t;
  flags: cint; aTimeOut: integer): ssize_t;
function ReadDWordFromSocket(aSock: longint): DWORD;
function ReadBytesFromSocket(aSock: longint; msg: pointer;
  len: size_t): ssize_t;
procedure WriteDWordToSocket(aSock: longint; aValue: DWORD);
function WriteBytesToSocket(aSock: longint; msg: pointer;
  len: size_t): ssize_t;
procedure WriteStreamToSocket(aSocket: longint;
  aSource: TMemoryStream);
procedure ReadStreamFromSocket(aSocket: longint;
  aSource: TMemoryStream);
{read|write to socket}

{rsa and session key functions}
procedure SendIsNewContact(aSocket: longint);
procedure SendIsOldContact(aSocket: longint);
function ReadIsNewContact(aSocket: longint): boolean;
procedure WritePublicKey(aSocket: longint; aRSAKey: TLbRSA);
procedure ReadPublicKey(aSocket: longint; aRSAKey: TLbRSA);
procedure SetSessionKey(aSocket: longint; aContact: TChatContact);
procedure ReadSessionKey(aSocket: longint; aContact: TChatContact);
procedure WriteSelfLinkToSocket(aSocket: longint;
  aContact: TChatContact);
procedure ReadContactLinkFromSocket(aSocket: longint;
  aContact: TChatContact);
procedure CheckRSAWriteString(aSocket: longint;
  aSource: string; aRSAKey: TLbRSA);
function CheckRSAReadString(aSocket: longint;
  aRSAKey: TLbRSA): string;
procedure ReadMaxProtocolVersion(aSocket: longint;
  aContact: TChatContact);
procedure SendMaxProtocolVersion(aSocket: longint;
  aContact: TChatContact);
{rsa and session key functions}

{messages functions}
function getTransfer(aSocket: longint): TTranferType;
procedure ReportPresenceMessage(aSocket: longint);
procedure ReadMessagesFromSocket(aSocket: longint;
  aContact: TChatContact);
procedure WriteMessagesToSocket(aSocket: longint;
  aContact: TChatContact);
procedure WriteMessageToSocket(aSocket: longint;
  aMessage: TChatMessage; aKey: string);
procedure ReadMessageFromSocket(aSocket: longint;
  aMessageList: TChatMessageList; aKey: string);
{messages functions}

{encript|decript functions}
procedure EncriptStream(aSource, aDest: TStream; aKey: string);
procedure DecriptStream(aSource, aDest: TStream; aKey: string);
procedure WriteEncriptedStreamToSocket(aSocket: longint;
  aSource: TStream; aKey: string);
procedure ReadDecriptedStreamFromSocket(aSocket: longint;
  aDest: TStream; aKey: string);
procedure WriteDWordEncripted(aSocket: longint; aVar: DWORD;
  aKey: string);
function ReadDWordDecripted(aSocket: longint; aKey: string): DWORD;
{encript|decript functions}

{links functions}
function ConnectToSocks5Host(aHost: string;
  aHostPort, aSocksPort: longint; aConnection : TChatConnection): longint;
function LinkFromTorHostAndPort(aHost: string;
  aOnionPort: word): string;
function TorHostFromLink(aLink: string): string;
function TorOnionPortFromLink(aLink: string): word;
{links functions}

implementation

uses LbAsym, Sockets, ChatFunctions,
  LbRandom, DCPrijndael, DCPsha256,
  BaseUnix, ChatUser, DCPblowfish;

function recvTimeOut(s: cint; buf: pointer; len: size_t;
  flags: cint; aTimeOut: integer; thread : TChatConnection): ssize_t;
var
  workTime: integer;
  def_flags: cint;
  vBuf: pointer;
  vLen: size_t;
  vRes: integer;
begin
  ProgramLogInfo('recvTimeOut begin ' + IntToStr(len) + ' byte');
  workTime := 0;
  Result := 0;

  def_flags := FpFcntl(s, F_GetFl, 0);
  FpFcntl(s, F_SetFl, def_flags or O_NONBLOCK);
  try

    vBuf := buf;
    vLen := len;
    vRes := -1;

    while (workTime < aTimeOut) and not thread.CheckTerminated do
    begin
      //ProgramLogInfo('Try to fprecv ' + IntToStr(vLen) + ' byte');
      vRes := fprecv(s, vBuf, vLen, flags);
      //ProgramLogInfo('fprecv ' + IntToStr(vRes) + ' byte');
      if (vRes = 0) then
        raise EChatNet.Create(
          'fprecv return 0 in non block mode')
      else if (vRes > 0) then
      begin
        Result += vRes;
        vLen -= vRes;
        vBuf := Pointer(vBuf + vRes);
      end;
      if Result = len then
        break;

      Sleep(100);
      workTime += 100;
    end;

  finally
    FpFcntl(s, F_SetFl, def_flags);
    ProgramLogInfo('recvTimeOut return ' + IntToStr(
      Result) + ' byte, after ' + IntToStr(workTime div 1000) + ' sec');
  end;

end;

function sendTimeOut(s: cint; msg: pointer; len: size_t;
  flags: cint; aTimeOut: integer): ssize_t;
var
  workTime: integer;
  def_flags: cint;
begin
  workTime := 0;
  Result := 0;

  def_flags := FpFcntl(s, F_GetFl, 0);
  FpFcntl(s, F_SetFl, def_flags or O_NONBLOCK);
  try

    while (workTime < aTimeOut) do
    begin
      Result := fpsend(s, msg, len, flags);
      if Result = 0 then
        raise EChatNet.Create(
          'fpsend return 0 in non block mode');
      if Result > 0 then
        break;

      Sleep(100);
      workTime += 100;
    end;

  finally
    FpFcntl(s, F_SetFl, def_flags);
  end;

end;

{read|write to socket}
function ReadDWordFromSocket(aSock: longint): DWORD;
begin
  if not (fprecv(aSock, @Result, 4, 0) = 4) then
  begin
    raise EChatNet.Create(
      'ReadDWordFromSocket read not 4 byte');
  end;
end;

function ReadBytesFromSocket(aSock: longint; msg: pointer;
  len: size_t): ssize_t;
begin
  Result := fprecv(aSock, msg, len, 0);
end;

procedure WriteDWordToSocket(aSock: longint; aValue: DWORD);
begin
  if not WriteBytesToSocket(aSock, @aValue, 4) = 4 then
    raise EChatNet.Create(
      'WriteDWordToSocket write not 4 byte');
end;

function WriteBytesToSocket(aSock: longint; msg: pointer;
  len: size_t): ssize_t;
begin
  Result := fpsend(aSock, msg, len, 0);
end;

procedure WriteStreamToSocket(aSocket: longint;
  aSource: TMemoryStream);
begin
  aSource.Position := 0;
  try
    WriteDWordToSocket(aSocket, aSource.Size);
  except
    on E: EChatNet do
      raise EChatNet.Create(
        'WriteStreamToSocket exception ' + E.Message);
  end;

  if not WriteBytesToSocket(aSocket, aSource.Memory, aSource.Size) =
    aSource.Size then raise EChatNet.Create(
      'Stream not sended in socket');
end;

procedure ReadStreamFromSocket(aSocket: longint;
  aSource: TMemoryStream);
var
  readSize: DWORD;
begin
  aSource.Position := 0;
  try
    readSize := ReadDWordFromSocket(aSocket);
  except
    on E: EChatNet do
      raise EChatNet.Create(
        'ReadStreamFromSocket exception ' + E.Message);
  end;
  aSource.SetSize(readSize);
  if not ReadBytesFromSocket(aSocket, aSource.Memory,
    aSource.Size) = readSize then
    raise EChatNet.Create('Stream not readed from socket');
end;

{read|write to socket}

{rsa and session key functions}

procedure SendIsNewContact(aSocket: longint);
begin
  try
    WriteDWordToSocket(aSocket, Ord(TTIsNewContact));
  except
    on E: EChatNet do
    begin
      raise EChatNet.Create(
        'SendIsNewContact exception ' + E.Message);
    end;
  end;
end;

procedure SendIsOldContact(aSocket: longint);
begin
  try
    WriteDWordToSocket(aSocket, Ord(TTIsOldContact));
  except
    on E: EChatNet do
    begin
      raise EChatNet.Create(
        'SendIsOldContact exception ' + E.Message);
    end;
  end;
end;

function ReadIsNewContact(aSocket: longint): boolean;
var
  v: DWORD;
begin

  try
    v := ReadDWordFromSocket(aSocket);
  except
    on E: EChatNet do
    begin
      raise EChatNet.Create(
        'ReadIsNewContact exception ' + E.Message);
    end;
  end;

  if v = Ord(TTIsNewContact) then
    Result := True
  else if v = Ord(TTIsOldContact) then
    Result := False
  else
    raise EChatNet.Create(
      'Error, contact not send info: new or old');
end;

procedure WritePublicKey(aSocket: longint; aRSAKey: TLbRSA);
var
  Source: TMemoryStream;
begin
  Source := TMemoryStream.Create;
  try
    Source.WriteByte(Ord(aRSAKey.KeySize));
    Source.WriteAnsiString(aRSAKey.Name);
    Source.WriteAnsiString(aRSAKey.PublicKey.ModulusAsString);
    Source.WriteAnsiString(aRSAKey.PublicKey.ExponentAsString);

    try
      WriteDWordToSocket(aSocket, Ord(TTPublicKey));
    except
      on E: EChatNet do
      begin
        raise EChatNet.Create(
          'WritePublicKey exception ' + E.Message);
      end;
    end;
    WriteStreamToSocket(aSocket, Source);
  finally
    Source.Free;
  end;
end;

procedure ReadPublicKey(aSocket: longint; aRSAKey: TLbRSA);
var
  Source: TMemoryStream;
  v: DWORD;
begin

  try
    v := ReadDWordFromSocket(aSocket);
  except
    on E: EChatNet do
    begin
      raise EChatNet.Create(
        'ReadPublicKey exception ' + E.Message);
    end;
  end;

  if not (v = Ord(TTPublicKey)) then
    raise EChatNet.Create('Contact not send public key');
  Source := TMemoryStream.Create;

  try
    ReadStreamFromSocket(aSocket, Source);

    aRSAKey.KeySize := TLbAsymKeySize(Source.ReadByte);
    aRSAKey.Name := Source.ReadAnsiString;
    aRSAKey.PublicKey.ModulusAsString := Source.ReadAnsiString;
    aRSAKey.PublicKey.ExponentAsString := Source.ReadAnsiString;

  finally
    Source.Free;
  end;
end;

procedure SetSessionKey(aSocket: longint; aContact: TChatContact);
var
  encriptedSessionKey: string;
  Source: TMemoryStream;
begin
  aContact.SessionKey := RandomString(SESSION_KEY_SIZE);
  encriptedSessionKey :=
    aContact.ContactRSAKey.EncryptString(aContact.SessionKey);

  Source := TMemoryStream.Create;
  try
    Source.WriteAnsiString(encriptedSessionKey);
    try
      WriteDWordToSocket(aSocket, Ord(TTSessionKey));
    except
      on E: EChatNet do
      begin
        raise EChatNet.Create(
          'SetSessionKey exception ' + E.Message);
      end;
    end;
    WriteStreamToSocket(aSocket, Source);
  finally
    Source.Free;
  end;
end;

procedure ReadSessionKey(aSocket: longint; aContact: TChatContact);
var
  Source: TMemoryStream;
  encriptedSessionKey, decryptedSessionKey: string;
  v: DWORD;
begin

  try
    v := ReadDWordFromSocket(aSocket);
  except
    on E: EChatNet do
    begin
      raise EChatNet.Create(
        'ReadSessionKey exception ' + E.Message);
    end;
  end;

  if not (v = Ord(TTSessionKey)) then
    raise EChatNet.Create('Contact not send session key');

  Source := TMemoryStream.Create;
  try
    ReadStreamFromSocket(aSocket, Source);

    encriptedSessionKey := Source.ReadAnsiString;
    decryptedSessionKey :=
      TChatUser(aContact.User).Key.DecryptString(
      encriptedSessionKey);
    aContact.SessionKey := decryptedSessionKey;

  finally
    Source.Free;
  end;

end;

procedure WriteSelfLinkToSocket(aSocket: longint;
  aContact: TChatContact);
var
  Source: TMemoryStream;
begin

  Source := TMemoryStream.Create;

  try

    try
      WriteDWordToSocket(aSocket, Ord(TTSendOnionLink));
    except
      on E: EChatNet do
      begin
        raise EChatNet.Create(
          'WriteSelfLinkToSocket exception ' + E.Message);
      end;
    end;

    Source.WriteAnsiString(TChatUser(aContact.User).getLink);
    WriteEncriptedStreamToSocket(aSocket,
      Source, aContact.SessionKey);
  finally
    Source.Free;
  end;
end;

procedure ReadContactLinkFromSocket(aSocket: longint;
  aContact: TChatContact);
var
  Source: TMemoryStream;
  v: DWORD;
begin

  try
    v := ReadDWordFromSocket(aSocket);
  except
    on E: EChatNet do
      raise EChatNet.Create(
        'ReadContactLinkFromSocket exception ' + E.Message);
  end;

  if not (v = Ord(TTSendOnionLink)) then
    raise EChatNet.Create('Contact not send self link');

  Source := TMemoryStream.Create;
  try
    ReadDecriptedStreamFromSocket(aSocket, Source,
      aContact.SessionKey);
    aContact.ContactLink := Source.ReadAnsiString;
  finally
    Source.Free;
  end;
end;

procedure CheckRSAWriteString(aSocket: longint;
  aSource: string; aRSAKey: TLbRSA);
var
  encripted: string;
  Source: TMemoryStream;
begin
  encripted := aRSAKey.EncryptString(aSource);

  Source := TMemoryStream.Create;
  try
    Source.WriteAnsiString(encripted);
    try
      WriteDWordToSocket(aSocket, Ord(TTCheckRSA));
    except
      on E: EChatNet do
        raise EChatNet.Create(
          'CheckRSAWriteString exception ' + E.Message);
    end;
    WriteStreamToSocket(aSocket, Source);
  finally
    Source.Free;
  end;
end;

function CheckRSAReadString(aSocket: longint;
  aRSAKey: TLbRSA): string;
var
  Source: TMemoryStream;
  encripted: string;
  v: DWORD;
begin

  Result := '';

  try
    v := ReadDWordFromSocket(aSocket);
  except
    on E: EChatNet do
      raise EChatNet.Create(
        'CheckRSAReadString exception ' + E.Message);
  end;

  if not (v = Ord(TTCheckRSA)) then
    raise EChatNet.Create('Contact not check RSA');

  Source := TMemoryStream.Create;
  try
    ReadStreamFromSocket(aSocket, Source);

    encripted := Source.ReadAnsiString;
    Result := aRSAKey.DecryptString(encripted);

  finally
    Source.Free;
  end;

end;

procedure ReadMaxProtocolVersion(aSocket: longint;
  aContact: TChatContact);
var
  Packet: TMemoryStream;
  maxTT, maxMC, transfers: DWORD;
begin
  Packet := TMemoryStream.Create;
  try
    ReadDecriptedStreamFromSocket(aSocket, Packet,
      aContact.SessionKey);
    transfers := Packet.ReadDWord;
    if transfers < PROTOCOL_VERSION_TRANSFERS then
      raise EChatNet.Create('Bad protocol version, ' +
        'TTranferType and TMessageCode not readed');
    maxTT := Packet.ReadDWord;
    maxMC := Packet.ReadDWord;
    aContact.SetMaxProtocolVersion(maxTT, maxMC);

    if transfers > PROTOCOL_VERSION_TRANSFERS then
      ProgramLogInfo('Contact ' + aContact.ContactRSAKey.Name +
        ' send ' + IntToStr(transfers) +
        ' instead PROTOCOL_VERSION_TRANSFERS=' + IntToStr(
        PROTOCOL_VERSION_TRANSFERS));

  finally
    Packet.Free;
  end;

end;

procedure SendMaxProtocolVersion(aSocket: longint;
  aContact: TChatContact);
var
  Packet: TMemoryStream;
begin
  Packet := TMemoryStream.Create;
  try
    Packet.WriteDWord(2); {count of dword in this transfer}
    Packet.WriteDWord(Ord(High(TTranferType)));
    Packet.WriteDWord(Ord(High(TMessageCode)));
    WriteEncriptedStreamToSocket(aSocket, Packet,
      aContact.SessionKey);
  finally
    Packet.Free;
  end;
end;

{rsa and session key functions}

{messages functions}
function getTransfer(aSocket: longint): TTranferType;
var
  def_flags: cint;
  answer: ssize_t;
begin
  Result := TTNON;
  { NOTE : this fuctions work in non block socket mode  }
  def_flags := FpFcntl(aSocket, F_GetFl, 0);
  FpFcntl(aSocket, F_SetFl, def_flags or O_NONBLOCK);

  try
    answer := fprecv(aSocket, @Result, 4, 0);
    if (answer = -1) then
    begin
      Result := TTNON;
    end
    else if answer = 0 then
    begin
      raise EChatNet.Create('fprecv return 0');
    end
    else if not answer = 4 then
    begin
      raise EChatNet.Create('getTransfer read not 4 bytes');
    end;
  finally
    FpFcntl(aSocket, F_SetFl, def_flags);
  end;

end;

procedure ReportPresenceMessage(aSocket: longint);
begin
  WriteDWordToSocket(aSocket, Ord(TTPresenseMessages));
end;

procedure ReadMessagesFromSocket(aSocket: longint;
  aContact: TChatContact);
var
  I, countToRead: integer;
begin

  countToRead := ReadDWordDecripted(aSocket, aContact.SessionKey);
  for I := 1 to countToRead do
  begin
    ReadMessageFromSocket(aSocket,
      aContact.Messages, aContact.SessionKey);
  end;

end;

procedure WriteMessagesToSocket(aSocket: longint;
  aContact: TChatContact);
var
  I, countToSend, sended: integer;
begin

  aContact.LockCriticalSection;

  try
    countToSend := 0;
    for I := 0 to aContact.Messages.Count - 1 do
    begin
      if not aContact.Messages.Items[I].Sended and
        (aContact.Messages.Items[I].Direction = MD_Outgoing) then
      begin
        Inc(countToSend);
      end;
    end;

  finally
    aContact.UnLockCriticalSection;
  end;

  WriteDWordEncripted(aSocket, countToSend, aContact.SessionKey);

  sended := 0;
  for I := 0 to aContact.Messages.Count - 1 do
  begin
    if not aContact.Messages.Items[I].Sended and
      (aContact.Messages.Items[I].Direction = MD_Outgoing) then
    begin
      if (sended >= countToSend) then Break;

      aContact.LockCriticalSection;
      try
        WriteMessageToSocket(aSocket,
          aContact.Messages.Items[I], aContact.SessionKey);
        aContact.Messages.Items[I].Sended := True;
      finally
        aContact.UnLockCriticalSection;
      end;

      Inc(sended);
    end;
  end;

end;

procedure WriteMessageToSocket(aSocket: longint;
  aMessage: TChatMessage; aKey: string);
var
  Packet: TMemoryStream;
begin
  Packet := TMemoryStream.Create;
  try
    Packet.WriteByte(Ord(aMessage.Code));
    aMessage.PackToSocketStream(Packet);
    WriteEncriptedStreamToSocket(aSocket, Packet, aKey);
  finally
    Packet.Free;
  end;
end;

procedure ReadMessageFromSocket(aSocket: longint;
  aMessageList: TChatMessageList; aKey: string);
var
  Packet: TMemoryStream;
  MCode: TMessageCode;
  Message: TChatMessage;
begin
  Packet := TMemoryStream.Create;
  try
    ReadDecriptedStreamFromSocket(aSocket, Packet, akey);
    MCode := TMessageCode(Packet.ReadByte);

    case MCode of
      MC_TextMessage:
      begin
        Message := TTextMessage.UnpackFromSocketStream(Packet,
          MD_Incoming);
        aMessageList.Add(Message);
      end;
      else
      begin
        raise EChatNet.Create('Unknown type of message recived');
      end;
    end;

  finally
    Packet.Free;
  end;

end;

{messages functions}

{encript|decript functions}
procedure EncriptStream(aSource, aDest: TStream; aKey: string);
var
  Cipher: TDCP_rijndael;
begin
  Cipher := TDCP_rijndael.Create(nil);
  if Cipher.SelfTest then
     WriteLn('Yes');
  try
    aSource.Position := 0;
    aDest.Position := 0;
    Cipher.InitStr(aKey, TDCP_sha256);
    Cipher.EncryptStream(aSource, aDest, aSource.Size);
    Cipher.Burn;
    aSource.Position := 0;
    aDest.Position := 0;
  finally
    Cipher.Free;
  end;
end;

procedure DecriptStream(aSource, aDest: TStream; aKey: string);
var
  Cipher: TDCP_rijndael;
begin
  Cipher := TDCP_rijndael.Create(nil);
  try
    aSource.Position := 0;
    aDest.Position := 0;
    Cipher.InitStr(aKey, TDCP_sha256);
    Cipher.DecryptStream(aSource, aDest, aSource.Size);
    Cipher.Burn;
    aSource.Position := 0;
    aDest.Position := 0;
  finally
    Cipher.Free;
  end;
end;

procedure WriteEncriptedStreamToSocket(aSocket: longint;
  aSource: TStream; aKey: string);
var
  Encripted: TMemoryStream;
begin
  Encripted := TMemoryStream.Create;
  try
    EncriptStream(aSource, Encripted, aKey);
    if (Encripted.Size >= High(word)) then
      raise EChatNet.Create('Ecripted stream size too big');
    WriteStreamToSocket(aSocket, Encripted);
  finally
    Encripted.Free;
  end;
end;

procedure ReadDecriptedStreamFromSocket(aSocket: longint;
  aDest: TStream; aKey: string);
var
  Source: TMemoryStream;
begin
  Source := TMemoryStream.Create;
  try
    ReadStreamFromSocket(aSocket, Source);
    DecriptStream(Source, aDest, aKey);
  finally
    Source.Free;
  end;
end;

procedure WriteDWordEncripted(aSocket: longint; aVar: DWORD;
  aKey: string);
var
  Source: TMemoryStream;
begin
  Source := TMemoryStream.Create;

  try
    Source.WriteDWord(aVar);
    WriteEncriptedStreamToSocket(aSocket, Source, aKey);
  finally
    Source.Free;
  end;

end;

function ReadDWordDecripted(aSocket: longint; aKey: string): DWORD;
var
  Source: TMemoryStream;
begin
  Source := TMemoryStream.Create;

  try
    ReadDecriptedStreamFromSocket(aSocket, Source, aKey);
    Result := Source.ReadDWord;
  finally
    Source.Free;
  end;

end;

{encript|decript functions}

{links functions}
function ConnectToSocks5Host(aHost: string;
  aHostPort, aSocksPort: longint; aConnection : TChatConnection): longint;
var
  SAddr: TInetSockAddr;
  Buffer: array[0..1024] of byte;
  x: integer;
  s: longint;
begin

  Result := -1;
  s := fpSocket(AF_INET, SOCK_STREAM, IPPROTO_IP);

  ProgramLogInfo('ConnectToSocks5Host create sock ' + IntToStr(s));

  if s = -1 then
  begin
    raise EChatNet.Create('fpSocket return -1');
  end;

  try

    with SAddr do
    begin
      sin_family := AF_INET;
      sin_port := htons(aSocksPort);
      sin_addr := StrToNetAddr('127.0.0.1');
    end;

    if fpconnect(s, @SAddr, sizeof(SAddr)) = -1 then
      raise EChatNet.Create(
        'fpconnect return -1, code  SocketError ' +
        IntToStr(SocketError));

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
    if not (recvTimeOut(s, @Buffer[0], 2, 0,
      IO_SOCKET_TIMEOUT,aConnection) = 2) then
      raise EChatNet.Create('first answer size error');

    if not (Buffer[0] = 5) or not (Buffer[1] = 0) then
      raise EChatNet.Create('first answer decode error');

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
    if not (recvTimeOut(s, @Buffer[0], 10, 0,
      IO_SOCKET_TIMEOUT, aConnection) = 10) then
      raise EChatNet.Create('second answer size error');

    if not (Buffer[0] = 5) or not (Buffer[1] = 0) then
    begin
      raise EChatNet.Create('second answer decode error');
    end;

    Result := s;

  except
    on E: EChatNet do
    begin
      ProgramLogInfo('ConnectToSocks5Host closed ' +
        IntToStr(s) + ', message ' + E.Message);
      CloseSocket(s);
      raise EChatNet.Create(
        'ConnectToSocks5Host exception: ' + E.Message);
    end;
  end;

end;

function LinkFromTorHostAndPort(aHost: string;
  aOnionPort: word): string;
begin
  Result := Copy(aHost, 0, Length(aHost) - 6);
  if not (aOnionPort = DEFAULT_ONION_PORT) then
    Result += ':' + IntToStr(aOnionPort);
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

{links functions}

end.
