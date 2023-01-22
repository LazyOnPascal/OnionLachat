unit ChatUser;

{$mode ObjFPC}{$H+}

interface

uses
  Classes,
  SysUtils,
  TorLauncher,
  ChatServer,
  ChatContactList,
  LbRSA,
  LbAsym;

type

  { TChatUser }

  TChatUser = class(TObject)
  private
    FName: string;
    FKey: TLbRSA;
    FServer: TChatServer;
    FTor: TTorLauncher;
    FContacts: TChatContactList;

  public
    constructor Create(aName: string; aTor: TTorLauncher; aKey: TLbRSA);
    destructor Destroy; override;

  public
    property Name: string read FName write FName;
    property Server: TChatServer read FServer;
    property Tor: TTorLauncher read FTor;
    property Contacts: TChatContactList read FContacts;
    property Key: TLbRSA read FKey;
  end;




implementation

uses
  Forms,
  ChatContact,
  Sockets;

{ TChatUser }

constructor TChatUser.Create(aName: string; aTor: TTorLauncher; aKey: TLbRSA);
begin
  FName := aName;
  FTor := aTor;
  FKey := aKey;
end;

destructor TChatUser.Destroy;
begin
  inherited Destroy;
end;

{ TChatUser }


end.
