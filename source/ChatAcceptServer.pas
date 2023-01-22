unit ChatAcceptServer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type

  { TChatAcceptServer }

  TChatAcceptServer = class(TThread)
  private
    FLocalPort: word;
  public
    constructor Create(aPort: word);
    destructor Destroy; override;
  protected
    procedure Execute; override;
  end;

implementation

uses
  ChatSocketProcedures;

{ TChatAcceptServer }

constructor TChatAcceptServer.Create(aPort: word);
begin
  FLocalPort := aPort;
  StartAcceptSocket(FLocalPort);

  //create thread
  inherited Create({False = start now}False);
  FreeOnTerminate := False;
  Priority := tpLower;
end;

destructor TChatAcceptServer.Destroy;
begin
  inherited Destroy;
end;

procedure TChatAcceptServer.Execute;
begin

end;

end.
