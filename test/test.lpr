program test;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, ChatTestCase, GuiTestRunner, ChatConnectionList;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

