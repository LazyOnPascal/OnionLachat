unit BridgeHelp;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TfBridge }

  TfBridge = class(TForm)
    gbGet: TGroupBox;
    lInfo: TLabel;
    lSite: TLabel;
    lMail: TLabel;
    lobfs4: TLabel;
    lip6: TLabel;
    lbr: TLabel;
    lInfo2: TLabel;
    procedure lSiteClick(Sender: TObject);
    procedure lMailClick(Sender: TObject);
    procedure lobfs4Click(Sender: TObject);
    procedure lip6Click(Sender: TObject);
    procedure lbrClick(Sender: TObject);
  private

  public

  end;

var
  fBridge: TfBridge;

implementation

uses
  Clipbrd;

{$R *.lfm}

{ TfBridge }

procedure TfBridge.lSiteClick(Sender: TObject);
begin
  Clipboard.AsText := 'bridges.torproject.org';
end;

procedure TfBridge.lMailClick(Sender: TObject);
begin
  Clipboard.AsText := 'bridges@torproject.org';
end;

procedure TfBridge.lobfs4Click(Sender: TObject);
begin
  Clipboard.AsText := 'get transport obfs4';
end;

procedure TfBridge.lip6Click(Sender: TObject);
begin
  Clipboard.AsText := 'get ipv6';
end;

procedure TfBridge.lbrClick(Sender: TObject);
begin
  Clipboard.AsText := 'get bridges';
end;

end.

