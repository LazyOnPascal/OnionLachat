unit GUIContacts;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ChatContactList, ChatContact, Forms, ExtCtrls,
  StdCtrls, Controls, GUIMessages, GUITypes;

type

  TSetActivMessagesListProc =
    procedure(aGUIMessageList: TGUIMessageList) of object;

  { TGUIContact }

  TGUIContact = class
  private
    FUserContact: TChatContact;
    FGUIPanel: TPanel;
    FGUILabel: TLabel;

    FGUIMessageList: TGUIMessageList;
    FSetActivMessagesListProc: TSetActivMessagesListProc;
  public
    FChecked: boolean;

  private
    procedure onClick(Sender: TObject);
  public
    constructor Create(aUserContact: TChatContact;
      aContactGUITemplateElements: TContactGUITemplateElements;
      aMessageGUITemplateElements: TMessageGUITemplateElements;
      aTopAnchor: TControl; aSetActivMessagesListProc: TSetActivMessagesListProc);
    destructor Destroy; override;
  public
    procedure Update;
  end;

  { TGUIContactList }

  TGUIContactList = class(TFPList)
  private
    FUserContacts: TChatContactList;
    FContactGUITemplateElements: TContactGUITemplateElements;
    FMessageGUITemplateElements: TMessageGUITemplateElements;
    FActiveGUIMessageList: TGUIMessageList;
    FNeedToReBuild: boolean;

  private
    function Get(Index: integer): TGUIContact;
    procedure OnAddContact(aContact: TChatContact);
    procedure OnDeleteContact(aContact: TChatContact);
    function Add(aUserContact: TChatContact): integer;
    procedure SetActiveMessageList(aGUIMessageList: TGUIMessageList);

  public
    constructor Create();
    destructor Destroy; override;
  public
    procedure Init(aUserContacts: TChatContactList;
      aContactTemplate: TContactGUITemplateElements;
      aMessagesTemplate: TMessageGUITemplateElements);
    procedure Update;
    procedure SendTextInActiveContact(aText: string);
  public
    property Items[Index: integer]: TGUIContact read Get; default;
    property ChatContacts: TChatContactList read FUserContacts;
  end;

implementation

uses
  LbRandom, Dialogs, Graphics, ChatMessage;

{ TGUIContact }

procedure TGUIContact.onClick(Sender: TObject);
begin
  //ShowMessage(self.FGUILabel.Caption);
  if not (FSetActivMessagesListProc = nil) then
    FSetActivMessagesListProc(self.FGUIMessageList);
end;

constructor TGUIContact.Create(aUserContact: TChatContact;
  aContactGUITemplateElements: TContactGUITemplateElements;
  aMessageGUITemplateElements: TMessageGUITemplateElements;
  aTopAnchor: TControl; aSetActivMessagesListProc: TSetActivMessagesListProc);
var
  stream: TMemoryStream;
begin
  FSetActivMessagesListProc := aSetActivMessagesListProc;
  FUserContact := aUserContact;
  FGUIMessageList := TGUIMessageList.Create(FUserContact,
    aMessageGUITemplateElements);

  stream := TMemoryStream.Create;

  stream.WriteComponent(
    aContactGUITemplateElements.pContactPanelTemplate);
  stream.WriteComponent(
    aContactGUITemplateElements.lContactLabelTemplate);
  stream.Position := 0;

  FGUIPanel := TPanel.Create(aContactGUITemplateElements.sbContactScrollBox);
  FGUILabel := TLabel.Create(FGUIPanel);
  stream.ReadComponent(FGUIPanel);
  stream.ReadComponent(FGUILabel);
  FGUILabel.Caption := aUserContact.ContactRSAKey.Name;
  FGUIPanel.Visible := True;



  FGUIPanel.Name := 'newpabel' + IntToStr(GetNewGuiNumber);
  FGUIPanel.Visible := True;
  FGUIPanel.parent := aContactGUITemplateElements.sbContactScrollBox;

  FGUILabel.Name := 'newlabel' + IntToStr(GetNewGuiNumber);
  FGUILabel.Visible := True;
  FGUILabel.parent := FGUIPanel;
  FGUILabel.OnClick := @self.onClick;

  if not (aTopAnchor = nil) then
  begin
    FGuiPanel.AnchorSideTop.Control := aTopAnchor;
    FGuiPanel.AnchorSideTop.Side := asrBottom;
  end
  else
  begin
    FGuiPanel.AnchorSideTop.Control := aContactGUITemplateElements.sbContactScrollBox;
  end;

  stream.Free;
end;

destructor TGUIContact.Destroy;
begin
  FGUIMessageList.Free;
  inherited Destroy;
end;

procedure TGUIContact.Update;
begin

  if self.FGUILabel.Caption = '' then
    self.FGUILabel.Caption := FUserContact.ContactRSAKey.Name;

  if self.FUserContact.Connection.Connected then
  begin
    FGUIPanel.Color := clLime;
  end
  else
  begin
    FGUIPanel.Color := clSilver;
  end;

  FGUIMessageList.Update;

end;

{ TGUIContactList }

constructor TGUIContactList.Create;
begin
  inherited;
  FActiveGUIMessageList := nil;
  FNeedToReBuild := False;
end;

destructor TGUIContactList.Destroy;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    Items[I].Free;
  end;
  inherited Destroy;
end;

function TGUIContactList.Add(aUserContact: TChatContact): integer;
var
  aTopAnchor: TControl;
begin
  aTopAnchor := nil;
  if (self.Count > 0) then
    aTopAnchor := self.Items[self.Count - 1].FGUIPanel;
  Result := inherited Add(TGUIContact.Create(aUserContact,
    FContactGUITemplateElements, FMessageGUITemplateElements,
    aTopAnchor, @self.SetActiveMessageList));
end;

procedure TGUIContactList.SetActiveMessageList(aGUIMessageList: TGUIMessageList);
begin
  if not (FActiveGUIMessageList = nil) then
  begin
    FActiveGUIMessageList.Hide;
  end;
  FActiveGUIMessageList := aGUIMessageList;
  FActiveGUIMessageList.Show;
end;

function TGUIContactList.Get(Index: integer): TGUIContact;
begin
  Result := TGUIContact(inherited get(Index));
end;

procedure TGUIContactList.OnAddContact(aContact: TChatContact);
begin
  FNeedToReBuild := True;
end;

procedure TGUIContactList.OnDeleteContact(aContact: TChatContact);
begin
  FNeedToReBuild := True;
end;

procedure TGUIContactList.Init(aUserContacts: TChatContactList;
  aContactTemplate: TContactGUITemplateElements;
  aMessagesTemplate: TMessageGUITemplateElements);
var
  i: integer;
  l: TLabel;
begin

  FUserContacts := aUserContacts;

  //contact list save and hide
  FContactGUITemplateElements := aContactTemplate;
  FContactGUITemplateElements.pContactPanelTemplate.Visible := False;

  //message list save and hide
  FMessageGUITemplateElements := aMessagesTemplate;
  FMessageGUITemplateElements.sbMessagesScrollBoxTemplate.Visible :=
    False;

  //create GUI contacts
  for i := 0 to (FUserContacts.Count - 1) do
  begin
    self.add(FUserContacts.Items[i]);
  end;
  //set contact callback
  FUserContacts.SetProc(@self.OnAddContact, @self.OnDeleteContact);

end;

procedure TGUIContactList.Update;
var
  i, ii: integer;
begin

  // пересборка контакт листа если изменился FUserContacts
  if FNeedToReBuild then
  begin

    for i := 0 to (self.Count - 1) do
      // отмечаем все сообщения в интефейсе не проверенными
    begin
      self.Items[i].FChecked := False;
    end;

    for i := 0 to (FUserContacts.Count - 1) do
      //перебираем все контакты
    begin
      if ((self.Count - 1) >= i) then
        //если такой индекс существует в gui
      begin
        if not (FUserContacts.Items[i] = self.Items[i].FUserContact) then
        begin // если гуи контакт не равен индексу в ядре
          self.Items[i].Free; // освобождаем гуи объект
          self.Delete(i);
          ii := self.Add(FUserContacts.Items[i]);
          //передавбавляем этот контакт
          self.Items[ii].FChecked := True;
        end
        else
        begin
          self.Items[i].FChecked := True; // всё норм, гуи правильный
        end;
      end
      else
      begin // если индекса не существет то создаём
        ii := self.Add(FUserContacts.Items[i]);
        self.Items[ii].FChecked := True;
      end;
    end;

    for i := 0 to (self.Count - 1) do
    begin //если остались непроверенные гуи обьекты - удаляем
      if not self.Items[i].FChecked then
      begin
        self.Items[i].Free;
        self.Delete(i);
      end;
    end;

    FNeedToReBuild := False;
  end;

  for I := 0 to Count - 1 do
  begin
    Items[I].Update;
    // обновление статуса(подключен или нет)
  end;
end;

procedure TGUIContactList.SendTextInActiveContact(aText: string);
var
  m: TTextMessage;
begin
  if not (FActiveGUIMessageList = nil) then
  begin
    m := TTextMessage.Create(aText);
    FActiveGUIMessageList.ChatContact.Messages.Add(m);
  end;
end;

end.
