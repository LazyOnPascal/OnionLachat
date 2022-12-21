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

  private
    procedure CreateGUIMessage(aGUITemplate: TMessageGUITemplateElements);

  public
    constructor Create(aMessage: TChatMessage; aParentScrollBox: TScrollBox;
      aPrevGUIMessage: TGUIMessage; aGUITemplate: TMessageGUITemplateElements);
    //нужно прописать создание мессаджа на экране из шаблона
    destructor Destroy; override;
  end;

  { TGUIMessageList }

  TGUIMessageList = class(TFPList)
  private
    FGUITemplate: TMessageGUITemplateElements;
    FMessagesScrollBox: TScrollBox;
    FChatContact: TChatContact;

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
      'messagepanel' + RandomString(GUI_ELEMENT_NAME_LENGTH);
    lMessageLabel.Name :=
      'messagelabel' + RandomString(GUI_ELEMENT_NAME_LENGTH);
    lMessageInfo.Name :=
      'messageinfo' + RandomString(GUI_ELEMENT_NAME_LENGTH);

    if FMessage is TTextMessage then
    begin
      lMessageLabel.Caption := TTextMessage(FMessage).Text;
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
  self.Add(aMessage);
end;

procedure TGUIMessageList.OnDeleteMessage(aMessage: TChatMessage);
var
  i: integer;
begin
  i := self.IndexOf(aMessage);
  if (i = -1) then exit;

  { TODO : Сделать перещёт привязок при удалении }

  Items[i].Free;
  inherited Delete(i);
end;

function TGUIMessageList.Add(aMessage: TChatMessage): integer;
var
  prev: TGUIMessage;
begin
  prev := nil;
  if (self.Count > 1) then prev := self.Items[self.Count - 1];
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
    'scrollbox' + RandomString(GUI_ELEMENT_NAME_LENGTH);

  FMessagesScrollBox :=
    TScrollBox.Create(FGUITemplate.pParentPanel);

  stream.ReadComponent(FMessagesScrollBox);
  FMessagesScrollBox.Name :=
    'scrollbox' + RandomString(GUI_ELEMENT_NAME_LENGTH);

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
  //todo скопировать все имеющиеся сообщения из aChatContact в лист
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

end.
