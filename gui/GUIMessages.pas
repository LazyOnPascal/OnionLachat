unit GUIMessages;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, ExtCtrls, StdCtrls, Controls, Forms,
  ChatMessage, ChatContact, GUITypes;

type

  { TGUIMessage }

  TGUIMessage = class(TObject)
  private
    FMessage: TChatMessage;
    FPrevGUIMessage: TGUIMessage;
    FParentScrollBox: TScrollBox;
    FMessageGUIElements: TMessageGUIElements;
  public
    FChecked: boolean;

  private
    procedure CreateGUIMessage(aGUITemplate: TMessageGUITemplateElements);

  public
    constructor Create(aMessage: TChatMessage; aParentScrollBox: TScrollBox;
      aPrevGUIMessage: TGUIMessage; aGUITemplate: TMessageGUITemplateElements);
    destructor Destroy; override;
  end;

  { TGUIMessageList }

  TGUIMessageList = class(TFPList)
  private
    FGUITemplate: TMessageGUITemplateElements;
    FMessagesScrollBox: TScrollBox;
    FChatContact: TChatContact;
    FNeedToReBuild: boolean;

  private
    function Get(Index: integer): TGUIMessage;
    procedure OnAddMessage(aMessage: TChatMessage);
    procedure OnDeleteMessage(aMessage: TChatMessage);
    function Add(aMessage: TChatMessage): integer;
    procedure CreateScrollBox;

  public
    constructor Create(aChatContact: TChatContact;
      aGUITemplate: TMessageGUITemplateElements);
    destructor Destroy; override;
  public
    procedure Show;
    procedure Hide;
    procedure Update;

  public
    property Items[Index: integer]: TGUIMessage read Get; default;
    property ChatContact: TChatContact read FChatContact;
  end;

implementation

uses
  LbRandom;

{ TGUIMessage }

constructor TGUIMessage.Create(aMessage: TChatMessage; aParentScrollBox: TScrollBox;
  aPrevGUIMessage: TGUIMessage; aGUITemplate: TMessageGUITemplateElements);
begin
  inherited Create;
  FMessage := aMessage;
  FPrevGUIMessage := aPrevGUIMessage;
  FParentScrollBox := aParentScrollBox;

  CreateGUIMessage(aGUITemplate);
end;

destructor TGUIMessage.Destroy;
begin

  inherited Destroy;
end;

procedure TGUIMessage.CreateGUIMessage(aGUITemplate: TMessageGUITemplateElements);
var
  stream: TMemoryStream;
begin
  //FMessageGUIElements
  stream := TMemoryStream.Create;

  stream.WriteComponent(
    aGUITemplate.pMessagePanelTemplate);
  stream.WriteComponent(
    aGUITemplate.lMessageLabelTemplate);
  stream.WriteComponent(
    aGUITemplate.lMessageInfoTemplate);
  stream.Position := 0;

  with FMessageGUIElements do
  begin
    pMessagePanel := TPanel.Create(FParentScrollBox);
    lMessageLabel := TLabel.Create(pMessagePanel);
    lMessageInfo := TLabel.Create(FParentScrollBox);

    stream.ReadComponent(pMessagePanel);
    stream.ReadComponent(lMessageLabel);
    stream.ReadComponent(lMessageInfo);

    pMessagePanel.Parent := FParentScrollBox;
    lMessageLabel.Parent := pMessagePanel;
    lMessageInfo.Parent := FParentScrollBox;

    pMessagePanel.Name :=
      'messagepanel' + IntToStr(GetNewGuiNumber);
    lMessageLabel.Name :=
      'messagelabel' + IntToStr(GetNewGuiNumber);
    lMessageInfo.Name :=
      'messageinfo' + IntToStr(GetNewGuiNumber);

    if FMessage is TTextMessage then
    begin
      lMessageLabel.Caption := TTextMessage(FMessage).Text;
      lMessageInfo.Caption:= FormatDateTime('dd.mm.yy, hh:nn', FMessage.Date);
    end;


    //lMessageLabel.AutoSize:=true;

    if not (FPrevGUIMessage = nil) then
    begin
      {pMessagePanel.Top :=
        FPrevGUIMessage.FMessageGUIElements.pMessagePanel.Top +
        FPrevGUIMessage.FMessageGUIElements.pMessagePanel.Height;  }
      pMessagePanel.AnchorSideTop.Control :=
        FPrevGUIMessage.FMessageGUIElements.lMessageInfo;
      pMessagePanel.AnchorSideTop.Side := asrBottom;
      lMessageInfo.AnchorSideTop.Control := pMessagePanel;
    end;

    if FMessage.Direction = TMessageDirection.MD_Outgoing then
    begin
      pMessagePanel.Anchors:= [akRight, akTop];
      pMessagePanel.AnchorSideRight.Side := asrRight;
      pMessagePanel.AnchorSideRight.Control := FParentScrollBox;
      lMessageInfo.Anchors:= [akRight, akTop];
      lMessageInfo.AnchorSideRight.Side := asrRight;
      lMessageInfo.AnchorSideRight.Control := pMessagePanel;
    end;

  end;

  stream.Free;
end;

{ TGUIMessageList }

function TGUIMessageList.Get(Index: integer): TGUIMessage;
begin
  Result := TGUIMessage(inherited get(Index));
end;

procedure TGUIMessageList.OnAddMessage(aMessage: TChatMessage);
begin
  FNeedToReBuild := true;
end;

procedure TGUIMessageList.OnDeleteMessage(aMessage: TChatMessage);
begin
  FNeedToReBuild := true;
end;

function TGUIMessageList.Add(aMessage: TChatMessage): integer;
var
  prev: TGUIMessage;
begin
  prev := nil;
  if (self.Count > 0) then prev := self.Items[self.Count - 1];
  Result := inherited Add(TGUIMessage.Create(
    aMessage, self.FMessagesScrollBox, prev, FGUITemplate));

  self.FMessagesScrollBox.VertScrollBar.Position :=
    self.FMessagesScrollBox.VertScrollBar.Range;
end;

procedure TGUIMessageList.CreateScrollBox;
var
  stream: TMemoryStream;
  bbl: TLabel;
begin
  stream := TMemoryStream.Create;

  stream.WriteComponent(
    FGUITemplate.sbMessagesScrollBoxTemplate);
  stream.Position := 0;

  FGUITemplate.sbMessagesScrollBoxTemplate.Name :=
    'scrollbox' + IntToStr(GetNewGuiNumber);

  FMessagesScrollBox :=
    TScrollBox.Create(FGUITemplate.pParentPanel);

  stream.ReadComponent(FMessagesScrollBox);
  FMessagesScrollBox.Name :=
    'scrollbox' + IntToStr(GetNewGuiNumber);

  FMessagesScrollBox.Parent := FGUITemplate.pParentPanel;

  stream.Free;
end;

constructor TGUIMessageList.Create(aChatContact: TChatContact;
  aGUITemplate: TMessageGUITemplateElements);
var
  I: integer;
begin
  inherited Create;

  FChatContact := aChatContact;
  FGUITemplate := aGUITemplate;
  CreateScrollBox;
  for I := 0 to aChatContact.Messages.Count - 1 do
  begin
    self.Add(aChatContact.Messages.Items[I]);
  end;
  aChatContact.Messages.SetProc(@self.OnAddMessage, @self.OnDeleteMessage);
end;

destructor TGUIMessageList.Destroy;
var
  I: integer;
begin
  for I := 0 to Count - 1 do
  begin
    Items[I].Free;
  end;
  inherited Destroy;
end;

procedure TGUIMessageList.Show;
begin
  FMessagesScrollBox.Visible := True;
end;

procedure TGUIMessageList.Hide;
begin
  FMessagesScrollBox.Visible := False;
end;

// пересборка всех сообщений
procedure TGUIMessageList.Update;
var
  i, ii : integer;
begin
  if FNeedToReBuild then
  begin

    for i := 0 to (self.Count - 1) do
    begin  // отмечаем все сообщения в интефейсе не проверенными
      self.Items[i].FChecked:=false;
    end;

    for i := 0 to (ChatContact.Messages.Count - 1) do
    begin
      if ((self.Count - 1) >= i) then //если такой индекс существует в gui
      begin
        if not ( ChatContact.Messages.Items[i] = self.Items[i].FMessage ) then
        begin // если гуи мессадж не равен индексу в ядре
          self.Items[i].Free; // освобождаем гуи объект
          self.Delete(i);
          ii := self.Add(ChatContact.Messages.Items[i]); //передавбавляем этот мессадж
          self.Items[ii].FChecked:=true;
        end else
        begin
          self.Items[i].FChecked:=true;
        end;
      end else
      begin // если индекса не существет то создаём
        ii := self.Add(ChatContact.Messages.Items[i]);
        self.Items[ii].FChecked:=true;
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

    FNeedToReBuild := false;
  end;
end;

end.
