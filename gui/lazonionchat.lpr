program lazonionchat;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, Main, BridgeHelp, GUI, GUIContacts, GUIMessages, GUITypes, NewUser;

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TfChat, fChat);
  Application.CreateForm(TfNewUser, fNewUser);
  Application.Run;
end.

