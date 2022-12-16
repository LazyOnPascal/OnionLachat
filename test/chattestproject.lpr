program chattestproject;

{$mode objfpc}{$H+}

uses
  cthreads, Interfaces, Forms, GuiTestRunner, test, TorLauncher, bridges;

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

