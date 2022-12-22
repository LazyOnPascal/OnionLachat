unit Main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ActnList, ExtCtrls,
  StdCtrls, Menus, ComCtrls, GUI;

const
  MB_OK = $00000000;
  MB_OKCANCEL = $00000001;
  MB_ABORTRETRYIGNORE = $00000002;
  MB_YESNOCANCEL = $00000003;
  MB_YESNO = $00000004;
  MB_RETRYCANCEL = $00000005;


  MB_ICONHAND = $00000010;
  MB_ICONQUESTION = $00000020;
  MB_ICONEXCLAMATION = $00000030;
  MB_ICONASTERICK = $00000040;
  MB_ICONWARNING = MB_ICONEXCLAMATION;
  MB_ICONERROR = MB_ICONHAND;
  MB_ICONINFORMATION = MB_ICONASTERICK;

  idOk = 1;
  ID_OK = idOk;
  idCancel = 2;
  ID_CANCEL = idCancel;
  idAbort = 3;
  ID_ABORT = idAbort;
  idRetry = 4;
  ID_RETRY = idRetry;
  idIgnore = 5;
  ID_IGNORE = idIgnore;
  idYes = 6;
  ID_YES = idYes;
  idNo = 7;
  ID_NO = idNo;
  IDCLOSE = 8;
  ID_CLOSE = IDCLOSE;
  IDHELP = 9;
  ID_HELP = IDHELP;

  FORM_CAPTION = 'OnionLachat';

type

  { TfChat }

  TfChat = class(TForm)
    bCopySelfLink: TButton;
    bSendMessage: TButton;
    bNewContact: TButton;
    lContactName: TLabel;
    lMessageText: TLabel;
    lMessageDate: TLabel;
    mTextInput: TMemo;
    pContact: TPanel;
    pMessage: TPanel;
    pMessages: TPanel;
    sbMessages: TScrollBox;
    sbStatus: TStatusBar;
    sbContacts: TScrollBox;
    tReconnect: TTimer;
    tStatusUpdate: TTimer;
    procedure bCopySelfLinkClick(Sender: TObject);
    procedure bNewContactClick(Sender: TObject);
    procedure bSendMessageClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure mAutoConnectClick(Sender: TObject);
    procedure mConnectionConnectClick(Sender: TObject);
    procedure mNewUserClick(Sender: TObject);
    procedure mSavaDataBaseClick(Sender: TObject);
    procedure mUserClick(Sender: TObject);
    procedure mUserCopyLinkClick(Sender: TObject);
    procedure pContactClick(Sender: TObject);
    procedure tReconnectTimer(Sender: TObject);
    procedure tStatusUpdateTimer(Sender: TObject);
  private

  public

  end;

var
  fChat: TfChat;

implementation

uses
  NewUser, LbRandom, GUITypes;

{$R *.lfm}

{ TfChat }

procedure TfChat.mUserClick(Sender: TObject);
begin

end;

procedure TfChat.mUserCopyLinkClick(Sender: TObject);
begin

end;

procedure TfChat.pContactClick(Sender: TObject);
begin

end;

procedure TfChat.tReconnectTimer(Sender: TObject);
begin
  if not assigned(gm.user) or not (gm.user.Tor.ready) then exit;
  gm.ReconnectConntact;
end;

procedure TfChat.tStatusUpdateTimer(Sender: TObject);
var
  status: string;
begin
  if (gm.user = nil) then exit;

  gm.UpdateTorStatus;
  gm.UpdateContactsAndMessages;

  status := '';
  if gm.user.Error then
  begin
    status := 'constructor error';
  end
  else if gm.user.Tor.error then
  begin
    status := 'tor error';
  end else if not gm.user.Tor.process.Running then
  begin
    status := 'OFFLINE';
    fChat.Caption := FORM_CAPTION + ' ' + status;
    sbStatus.Color := clSilver;
  end
  else
  begin
    status := 'CONNECTING';
    fChat.Caption := FORM_CAPTION + ' ' + status;
    sbStatus.Color := clCream;
  end;

  if gm.user.Tor.ready then
  begin
    status := 'ONLINE';
    fChat.Caption := FORM_CAPTION + ' ' + status;
    sbStatus.Color := clMoneyGreen;
    if not tReconnect.Enabled then
    begin
      gm.ReconnectConntact;
      tReconnect.Enabled := True;
    end;
  end;
  sbStatus.Panels.Items[0].Text :=
    gm.user.Name + ' ' + status;

end;

procedure TfChat.FormCreate(Sender: TObject);
begin
  gm := TGUIMaster.Create();
end;

procedure TfChat.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  gm.SaveData;
end;

procedure TfChat.bNewContactClick(Sender: TObject);
begin
  gm.NewContact;
end;

procedure TfChat.bSendMessageClick(Sender: TObject);
var
  stream: TMemoryStream;
  l: TLabel;
  sb: TScrollBox;
begin
  if not (mTextInput.Text = '') then
  begin
    gm.contacts.SendTextInActiveContact(mTextInput.Text);
    mTextInput.Text := '';
  end;
end;

procedure TfChat.bCopySelfLinkClick(Sender: TObject);
begin
  gm.GetLink;
end;

procedure TfChat.FormDestroy(Sender: TObject);
begin
  gm.Free;
end;

procedure TfChat.FormShow(Sender: TObject);
var
  resp: integer;
  aContactTemplate: TContactGUITemplateElements;
  aMessagesTemplate: TMessageGUITemplateElements;
begin
  try

    if not gm.DataBaseExists then
    begin
      if not assigned(gm.user) then mNewUserClick(Sender);
      Exit;
    end;

    repeat
      if gm.LoadData('') or gm.LoadData(
        PasswordBox('LazOnionChat',
        'Enter password')) then break;
      resp := Application.MessageBox(
        'Bad password', 'LazOnionChat',
        MB_ICONQUESTION + MB_RETRYCANCEL);
    until not (resp = idRetry);

  finally

    if not (gm.user = nil) then
    begin
      if gm.autostart then gm.Connect;
      //fChat.mAutoConnect.Checked := gm.autostart;
      tStatusUpdate.Enabled := True;

      aContactTemplate.sbContactScrollBox := sbContacts;
      aContactTemplate.pContactPanelTemplate := pContact;
      aContactTemplate.lContactLabelTemplate := lContactName;
      aMessagesTemplate.pParentPanel := pMessages;
      aMessagesTemplate.sbMessagesScrollBoxTemplate :=
        sbMessages;
      aMessagesTemplate.pMessagePanelTemplate :=
        pMessage;
      aMessagesTemplate.lMessageLabelTemplate :=
        lMessageText;
      aMessagesTemplate.lMessageInfoTemplate :=
        lMessageDate;
      gm.contacts.Init(gm.user.Contacts, aContactTemplate,
        aMessagesTemplate);

      {gm.InitContactsGUI(sbContacts, pContact, lContactName,
        sbMessages, pMessage,
        lMessageText, lMessageDate);  }
    end;

    tStatusUpdate.Enabled := True;

  end;
end;

procedure TfChat.mAutoConnectClick(Sender: TObject);
begin
  //gm.autostart := mAutoConnect.Checked;
end;

procedure TfChat.mConnectionConnectClick(Sender: TObject);
begin
  gm.Connect;
end;

procedure TfChat.mNewUserClick(Sender: TObject);
begin
  fNewUser.SetDefaults;
  fNewUser.ShowModal;
end;

procedure TfChat.mSavaDataBaseClick(Sender: TObject);
begin

end;

end.
