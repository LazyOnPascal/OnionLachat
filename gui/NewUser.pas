unit NewUser;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ComCtrls;

type

  { TfNewUser }

  TfNewUser = class(TForm)
    bCreate: TButton;
    cbKeyLength: TComboBox;
    cbAutoStart: TCheckBox;
    eBridge1: TEdit;
    eBridge2: TEdit;
    eBridge3: TEdit;
    eName: TEdit;
    eHostPort: TEdit;
    eSocksPort: TEdit;
    eTorBinDir: TEdit;
    eTorConfigDir: TEdit;
    ePassword1: TEdit;
    ePassword2: TEdit;
    gbBridge: TGroupBox;
    fbExtendet: TGroupBox;
    gbGeneralSettings: TGroupBox;
    lInfo: TLabel;
    lBridgeHelp: TLabel;
    lKeyLength: TLabel;
    lName: TLabel;
    lName1: TLabel;
    lName2: TLabel;
    lName3: TLabel;
    lName4: TLabel;
    lPassword: TLabel;
    procedure bCreateClick(Sender: TObject);
    procedure lBridgeHelpClick(Sender: TObject);
    procedure SetDefaults;
  private

  public

  end;

var
  fNewUser: TfNewUser;

implementation

uses
  LbAsym, BridgeHelp, GUI, TorLauncher, LbRandom, ChatProtocol, Main;

{$R *.lfm}

{ TfNewUser }

procedure TfNewUser.lBridgeHelpClick(Sender: TObject);
begin
  fBridge.ShowModal;
end;

procedure TfNewUser.SetDefaults;
begin
  eName.Text:='User'+RandomString(6);
  eHostPort.Text:=IntToStr(DEFAULT_ONION_PORT);
  eSocksPort.Text:=IntToStr(DEFAULT_SOCKS_PORT);
  eTorBinDir.Text:='';
  eTorConfigDir.Text:='data/'+RandomString(6);
  cbAutoStart.Checked:=true;
end;

procedure TfNewUser.bCreateClick(Sender: TObject);
var
  vKeySize: TLbAsymKeySize;
  autoSt : boolean;
begin
  case cbKeyLength.ItemIndex of
    0: vKeySize := aks128;
    1: vKeySize := aks256;
    2: vKeySize := aks512;
    3: vKeySize := aks768;
    4: vKeySize := aks1024;
    5: vKeySize := aks2048;
    6: vKeySize := aks3072;
    else
      vKeySize := aks1024;
  end;

  autoSt := false;
  if cbAutoStart.Checked then autoSt := true;

  { TODO : проверка двойного введения пароля}
  gm.pass:=ePassword1.Text;

  gm.NewUser(eName.Text, vKeySize, StrToInt(eHostPort.Text),
  StrToInt(eSocksPort.Text),eTorBinDir.Text,eTorConfigDir.Text,
    TTorBridges.Create(eBridge1.Text,
    eBridge2.Text, eBridge3.Text));
  gm.autostart:= autoSt;
  gm.SaveData;

  fChat.mAutoConnect.Checked:=autoSt;

  Close;
end;

end.
