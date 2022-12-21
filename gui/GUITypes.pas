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

const
  GUI_ELEMENT_NAME_LENGTH = 128;

implementation

end.

