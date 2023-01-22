unit ChatSocketMessage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type

  { TChatSocketMessage }

  TChatSocketMessage = class
  private
    FData: array of byte;
    FDataSize: longint;
    FDecoded: boolean;
    FHashError: boolean;
    FSizeInBuf: longint;
  public
    constructor Create(aBuffer: array of byte; aSize: longint);
    destructor Destroy; override;
  private
    function hashEqual(aHash1, aHash2: array of byte):boolean;
  public
    property Decoded: boolean read FDecoded;
    property HashError: boolean read FHashError;
    property UsedBytesFromSource: longint read FSizeInBuf;
  end;

implementation

uses
  DCPsha256;

{ TChatSocketMessage }

constructor TChatSocketMessage.Create(aBuffer: array of byte; aSize: longint);
var
  sizeOfPack: PLongInt;
  hash: array[0..31] of byte;
  dcp: TDCP_sha256;
begin
  FDecoded:=false;
  FHashError:=false;
  FSizeInBuf:=0;

  if (aSize < (4+32)) then exit;

  sizeOfPack := @aBuffer[0];
  if (sizeOfPack^ < (aSize-(4+32)) ) then exit;
  dcp:= TDCP_sha256.Create(nil);
  dcp.Init;
  dcp.Update(aBuffer[4+32],aSize-(4+32));
  dcp.Final(hash);
  dcp.Free;
  if not hashEqual(hash,aBuffer[4]) then
  begin
    FHashError := true;
    exit;
  end;

  FSizeInBuf :=  sizeOfPack^ + (4+32);
  FData := @aBuffer[4+32];
  FDataSize := sizeOfPack^;
  FDecoded := true;
end;

destructor TChatSocketMessage.Destroy;
begin
  inherited Destroy;
end;

function TChatSocketMessage.hashEqual(aHash1, aHash2: array of byte): boolean;
var
  i:Longint;
begin
  Result := true;
  for i:=0 to 31 do
  begin
    if aHash1[i] <> aHash2[i] then
    begin
      Result := false;
      break;
    end;
  end;
end;

end.
