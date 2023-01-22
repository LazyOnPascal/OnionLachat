unit ChatLog;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils {$ifdef Unix}, Unix {$endif};

procedure ProgramLogError(aError: string);
procedure ProgramLogInfo(aText: string);
procedure ProgramLogDebug(aText: string);

implementation

procedure ProgramLogError(aError: string);
var
  st: string;
begin
  st := IntToStr(GetCurrentThreadID());
  Writeln('ERROR ', TimeToStr(Time), ' (', Copy(st, Length(st) - 4, 4), ') ', aError);
  //GetCurrentThreadID() // Windows;
  //GetThreadID() // Darwin (macOS); FreeBSD;
  //TThreadID(pthread_self) // Linux;
end;

procedure ProgramLogInfo(aText: string);
var
  st: string;
begin
  st := IntToStr(GetCurrentThreadID());
  Writeln(TimeToStr(Time), ' (', Copy(st, Length(st) -
    4, 4), ') ', aText);
end;

procedure ProgramLogDebug(aText: string);
var
  st: string;
begin
  {$IFOPT D+}
  st := IntToStr(GetCurrentThreadID());
  Writeln(TimeToStr(Time), ' (', Copy(st, Length(st) -
    4, 4), ') ', aText);
  {$ENDIF}
end;



{----------------------------------------------------------------------------}



end.

