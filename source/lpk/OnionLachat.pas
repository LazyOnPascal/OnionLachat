{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit OnionLachat;

{$warn 5023 off : no warning about unused units}
interface

uses
  ChatUser, ChatLog, ChatServer, ChatConnectionList, ChatConnection, 
  ChatContact, ChatContactList, ChatAcceptedConnectionList, 
  ChatAcceptedConnection, ChatSocketProcedures, ChatTypes, ChatSocket, 
  ChatSocketMessage, LinkConnector, ChatConst, LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('OnionLachat', @Register);
end.
