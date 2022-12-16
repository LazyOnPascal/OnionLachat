unit CommonFunctions;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Unix;

type
  EFileStream = class(Exception);

procedure CreateFileFromStream(aFilePath: string; aStream: TStream);
procedure ProgramLogError(aError: string);
procedure ProgramLogInfo(aText: string);

implementation

procedure CreateFileFromStream(aFilePath: string; aStream: TStream);
var
  fsRead, fsCreate: TFileStream;
begin
  try
    fsRead := TFileStream.Create(aFilePath, fmOpenRead);
    fsRead.Free;
  except
    on E: EFOpenError do
    begin
      {file not exist - lets create it}
      try
        fsCreate := TFileStream.Create(aFilePath, fmCreate);
        fsCreate.CopyFrom(aStream, aStream.Size);
        fsCreate.Free;
      except
        raise EFileStream.Create(
          'Some error while create geoip file');
      end;
    end;
  end;

end;

procedure ProgramLogError(aError: string);
var
  st: string;
begin
  st := IntToStr(GetCurrentThreadID());
  Writeln('ERROR ',TimeToStr(Time), ' (', Copy(st, Length(st) -
    4, 4), ') ', aError);
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



{----------------------------------------------------------------------------}



end.
