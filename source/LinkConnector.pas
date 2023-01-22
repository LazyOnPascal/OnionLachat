unit LinkConnector;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils,
  LbRSA,
  ChatTypes,
  PollList;

type

  { TLinkConnector }

  TLinkConnector = class
  public
    constructor Create(aLink : string; aContactKey: TLbRSA;
      aUserKey: TLbRSA; aPollList: TPollList; aOnConnected: TOnConnected);
  end;

implementation

{ TLinkConnector }

constructor TLinkConnector.Create(aLink : string; aContactKey: TLbRSA;
      aUserKey: TLbRSA; aPollList: TPollList; aOnConnected: TOnConnected);
begin

end;

end.

