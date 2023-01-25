{ This file was automatically created by Lazarus. Do not edit!
  This source is only used to compile and install the package.
 }

unit OnionLachat;

{$warn 5023 off : no warning about unused units}
interface

uses
  ChatProtocol, Bridges, ChatConnection, CommonFunctions, ChatFunctions, 
  ChatMessage, ChatUser, ChatMessageList, ChatContactList, ChatContact, 
  LazarusPackageIntf;

implementation

procedure Register;
begin
end;

initialization
  RegisterPackage('OnionLachat', @Register);
end.
