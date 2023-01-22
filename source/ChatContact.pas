unit ChatContact;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  LbRSA;

type

  { TChatContact }

  TChatContact = class
  private
    FName: string;
    FRSA: TLbRSA;
    FLink: string;

  public
    constructor Create(aName, aLink: string);
    destructor Destroy; override;

  public
    property Name: string read FName;
    property Key: TLbRSA read FRSA;
    property Link: string read FLink;

  end;

implementation

{ TChatContact }

constructor TChatContact.Create(aName, aLink: string);
begin
  FName := aName;
  FLink := aLink;
end;

destructor TChatContact.Destroy;
begin
  if assigned(FRSA) then FRSA.Free;
  inherited Destroy;
end;

end.

