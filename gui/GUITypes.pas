unit GUITypes;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, ExtCtrls, StdCtrls, Controls;

type

  TContactGUITemplateElements = record
    sbContactScrollBox: TScrollBox;
    pContactPanelTemplate: TPanel;
    lContactLabelTemplate: TLabel;
  end;

  TMessageGUITemplateElements = record
    pParentPanel: TPanel;
    sbMessagesScrollBoxTemplate: TScrollBox;
    pMessagePanelTemplate: TPanel;
    lMessageLabelTemplate: TLabel;
    lMessageInfoTemplate: TLabel;
  end;

  TMessageGUIElements = record
    pMessagePanel: TPanel;
    lMessageLabel: TLabel;
    lMessageInfo: TLabel;
  end;

  function GetNewGuiNumber : Uint64;

implementation

var
  GuiElementCounter : Uint64 = 0;

function GetNewGuiNumber: Uint64;
begin
  inc(GuiElementCounter);
  Result := GuiElementCounter;
end;

end.

