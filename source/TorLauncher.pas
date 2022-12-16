unit TorLauncher;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Process, Forms;

type

  ETorLauncher = class(Exception);

  { TTorBridges }

  TTorBridges = class
  private
    FBridge1: string;
    FBridge2: string;
    FBridge3: string;
  public
    constructor Create(aB1, aB2, aB3: string);
    constructor LoadFromStream(aStream: TStream);
  public
    procedure PackToStream(aStream: TStream);
  public
    property bridge1: string read FBridge1;
    property bridge2: string read FBridge2;
    property bridge3: string read FBridge3;
  end;

  { TTorLauncher }

  TTorLauncher = class
  private
  const
    ConfigFileNameConst: string = '/torrc';
  var
    FTorDir: string;
    FWorkDir: string;
    FOnionPort: word;
    FSocksPort: word;
    FBridges: TTorBridges;

    FProcess: TProcess;
    FTorError: boolean;
    FReady: boolean;
    FFullConsoleOutput: string;

  public
    constructor Create(aTorDir, aWorkDir: string;
      aOnionPort: word; aSocksPort: word; aBridges: TTorBridges);
    constructor LoadFromStream(aStream: TStream);
    destructor Destroy; override;

  public
    procedure Execute;
    procedure KillProcess;
    procedure Restart;
    function GetNewOutput: string;
    function TorReadyToWork: boolean;
    procedure PackToStream(aStream: TStream);

  private
    procedure BuildTorrcFile;
    procedure CreateGEOIPFile;
    function GetHostName: string;
    procedure InitFiles;

  public
    property ready: boolean read TorReadyToWork;
    property error: boolean read FTorError;
    property process: TProcess read FProcess;
    property onionPort: word read FOnionPort;
    property socksPort: word read FSocksPort;
    property host: string read GetHostName;


  end;

{$R geoip.rc}

implementation

uses
  FileUtil, BaseUnix, CommonFunctions;

{ TTorBridges }

constructor TTorBridges.Create(aB1, aB2, aB3: string);
begin
  FBridge1 := aB1;
  FBridge2 := aB2;
  FBridge3 := aB3;
end;

constructor TTorBridges.LoadFromStream(aStream: TStream);
begin
  FBridge1 := aStream.ReadAnsiString;
  FBridge2 := aStream.ReadAnsiString;
  FBridge3 := aStream.ReadAnsiString;
end;

procedure TTorBridges.PackToStream(aStream: TStream);
begin
  aStream.WriteAnsiString(FBridge1);
  aStream.WriteAnsiString(FBridge2);
  aStream.WriteAnsiString(FBridge3);
end;

{ TTorLauncher }

{ TODO : передовать не локацию tor.exe а локацию со всеми допами тора }

constructor TTorLauncher.Create(aTorDir, aWorkDir: string;
  aOnionPort: word; aSocksPort: word; aBridges: TTorBridges);
begin
  FWorkDir := aWorkDir;
  FOnionPort := aOnionPort;
  FSocksPort := aSocksPort;
  FTorDir := aTorDir;
  FBridges := aBridges;

  FProcess := TProcess.Create(nil);
  FReady := False;
  FTorError := False;
  FFullConsoleOutput := '';
  InitFiles; //init tor files
end;

constructor TTorLauncher.LoadFromStream(aStream: TStream);
var
  tor, dir: string;
  onion, socks: word;
  b: TTorBridges;
begin
  { TODO : сделать распаковку тор хост ключа }
  tor := aStream.ReadAnsiString;
  dir := aStream.ReadAnsiString;
  onion := aStream.ReadWord;
  socks := aStream.ReadWord;
  b := TTorBridges.LoadFromStream(aStream);
  self.Create(tor, dir, onion, socks, b);
end;

procedure TTorLauncher.PackToStream(aStream: TStream);
begin
  { TODO : сделать запаковку тор хост ключа }
  aStream.WriteAnsiString(FTorDir);
  aStream.WriteAnsiString(FWorkDir);
  aStream.WriteWord(FOnionPort);
  aStream.WriteWord(FSocksPort);
  FBridges.PackToStream(aStream);
end;


destructor TTorLauncher.Destroy;
begin
  Self.KillProcess;
  FBridges.Free;
  inherited Destroy;
end;

procedure TTorLauncher.InitFiles;
begin
  if not ForceDirectories(FWorkDir) or not
    ForceDirectories(FWorkDir + '/host') or not
    ForceDirectories(FWorkDir + '/onion-auth') or
    not (FpChmod(FWorkDir + '/host', S_IRUSR or
    S_IWUSR or S_IXUSR) = 0) then
    raise ETorLauncher.Create('Work path error');

  CreateGEOIPFile;

  FProcess.Executable := FindDefaultExecutablePath(FTorDir + 'tor');
  if FProcess.Executable = '' then
    raise ETorLauncher.Create('Tor bin not found');

  FProcess.Parameters.Add('--DataDirectory');
  FProcess.Parameters.Add(FWorkDir);
  FProcess.Parameters.Add('-f');
  FProcess.Parameters.Add(FWorkDir + ConfigFileNameConst);
  FProcess.Options := [poUsePipes];

  BuildTorrcFile;
end;

procedure TTorLauncher.Execute;
begin
  FProcess.Execute;
end;

procedure TTorLauncher.KillProcess;
begin
  if (FProcess.Running) then
    FProcess.Terminate(-1);
  Self.FProcess.Free;
  FFullConsoleOutput := '';
end;

procedure TTorLauncher.Restart;
var
  tor, dir: string;
  onion, socks: word;
  b: TTorBridges;
begin
  if (FProcess.Running) then
    FProcess.Terminate(-1);
  tor := FTorDir;
  dir := FWorkDir;
  onion := FOnionPort;
  socks := FSocksPort;
  b := TTorBridges.Create(FBridges.bridge1, FBridges.bridge2,
    FBridges.bridge3);
  self.Free;
  self := TTorLauncher.Create(tor, dir, onion, socks, b);
  self.Execute;
  //FProcess.Free;
  //FFullConsoleOutput := '';
  //Execute;
end;

function TTorLauncher.GetNewOutput: string;
const
  BUF_SIZE = 2048;
var
  BytesRead: longint;
  Buffer: array[1..BUF_SIZE] of byte;
  AnsiStr: string;
begin
  Buffer[1] := 0;
  Result := '';
  while (FProcess.Output.NumBytesAvailable > 0) do
  begin
    BytesRead := FProcess.Output.Read(Buffer, BUF_SIZE);
    SetString(AnsiStr, pansichar(@Buffer[1]), BytesRead);
    Result += AnsiStr;
    FFullConsoleOutput += AnsiStr;
  end;
  if (Pos('[err]', FFullConsoleOutput) > 0) then
  begin
    FTorError := True;
  end;
end;

function TTorLauncher.GetHostName: string;
var
  HostFile: TextFile;
begin
  AssignFile(HostFile, FWorkDir + '/host/hostname');
  Result := '';
  try
    Reset(HostFile);
    Readln(HostFile, Result);
    if Result = '' then
      raise ETorLauncher.Create('Host name read error');
  finally
    CloseFile(HostFile);
  end;
end;

function TTorLauncher.TorReadyToWork: boolean;
begin
  if FReady then exit(True);
  Result := False;
  //self.GetNewOutput;
  if (Pos('Bootstrapped 100% (done)', FFullConsoleOutput) > 0) then
  begin
    FReady := True;
    exit(True);
  end;

end;

procedure TTorLauncher.BuildTorrcFile;
var
  TorccFile: TextFile;
begin
  AssignFile(TorccFile, FWorkDir + ConfigFileNameConst);

    {$i-}
  Rewrite(TorccFile);
    {$i+}
  if IOresult <> 0 then
    raise ETorLauncher.Create('Torrc file creating error');

  if (FBridges.bridge1.Length > 0) then
    Writeln(TorccFile, 'Bridge ' + FBridges.bridge1);
  if (FBridges.bridge2.Length > 0) then
    Writeln(TorccFile, 'Bridge ' + FBridges.bridge2);
  if (FBridges.bridge3.Length > 0) then
    Writeln(TorccFile, 'Bridge ' + FBridges.bridge3);
  Writeln(TorccFile, 'ClientOnionAuthDir ' + FWorkDir +
    '/onion-auth');
  Writeln(TorccFile, 'GeoIPFile ' + FWorkDir + '/geoip');
  Writeln(TorccFile, 'GeoIPv6File ' + FWorkDir + '/geoip6');
  Writeln(TorccFile, 'HiddenServiceDir ' + FWorkDir + '/host');
  Writeln(TorccFile, 'HiddenServicePort ' +
    IntToStr(FOnionPort) + ' 127.0.0.1:' + IntToStr(FOnionPort));
  Writeln(TorccFile, 'SocksPort ' + IntToStr(FSocksPort));

  //Writeln(TorccFile, 'ProtocolWarnings 1');
  if (FBridges.bridge1.Length > 0) or
    (FBridges.bridge2.Length > 0) or
    (FBridges.bridge3.Length > 0) then
    Writeln(TorccFile, 'UseBridges 1');


  Writeln(TorccFile, 'AvoidDiskWrites 1');
  Writeln(TorccFile, 'Log notice stdout');
  Writeln(TorccFile, 'CookieAuthentication 1');
  Writeln(TorccFile, 'DormantCanceledByStartup 1');
  Writeln(TorccFile,
    'ClientTransportPlugin meek_lite,obfs2,obfs3,obfs4,scramblesuit exec '
    + FTorDir + 'PluggableTransports/obfs4proxy ');

  CloseFile(TorccFile);
end;

procedure TTorLauncher.CreateGEOIPFile;
var
  sResource: TResourceStream;
begin
  sResource := TResourceStream.Create(HInstance, 'GEOIP', RT_RCDATA);
  try
    CreateFileFromStream(FWorkDir + '/geoip', sResource);
  finally
    sResource.Free;
  end;
  sResource := TResourceStream.Create(HInstance,
    'GEOIP6', RT_RCDATA);
  try
    CreateFileFromStream(FWorkDir + '/geoip6', sResource);
  finally
    sResource.Free;
  end;
end;


end.
