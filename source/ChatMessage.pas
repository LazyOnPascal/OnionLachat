unit ChatMessage;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils;

type

  TMessageCode = (MC_Non=0, MC_TextMessage);
  TMessageDirection = (MD_Non=0, MD_Incoming, MD_Outgoing);

  { TChatMessage }

  TChatMessage = class(TObject)
  private
    FSended: boolean;
    FCode: TMessageCode;
    FDataLength: DWORD;
    FDirection: TMessageDirection;
    FTimeCreated : TDateTime;

  public
    constructor Create(aDirection: TMessageDirection);
    constructor LoadFromStream(aStream: TStream); virtual; abstract;
    destructor Destroy; override;

  public
    procedure PackToSocketStream(aStream: TStream); virtual; abstract;
    procedure PackToStream(aStream: TStream); virtual; abstract;

  public
    property Sended: boolean read FSended write FSended;
    property Direction: TMessageDirection read FDirection;
    property Code: TMessageCode read FCode;
    property Date: TDateTime read FTimeCreated;

  end;

  { TTextMessage }

  TTextMessage = class(TChatMessage)
  private
    FText: string;
  public
    constructor Create(aText: string;
      aDirection: TMessageDirection = MD_Outgoing);
    constructor UnpackFromSocketStream(aStream: TStream;
      aDirection: TMessageDirection = MD_Incoming);
    constructor LoadFromStream(aStream: TStream); override;
    destructor Destroy; override;
  public
    procedure PackToSocketStream(aStream: TStream); override;
    procedure PackToStream(aStream: TStream); override;

  public
    property Text: string read FText;
  end;

implementation

{ TChatMessage }

constructor TChatMessage.Create(aDirection: TMessageDirection);
begin
  inherited Create;
  FCode := MC_Non;
  FDataLength := 0;
  FDirection := aDirection;
  FTimeCreated := Now;
  if (aDirection = MD_Incoming) then FSended := True
  else
    FSended := False;
end;

destructor TChatMessage.Destroy;
begin
  inherited Destroy;
end;

{ TChatMessage }


{ TTextMessage }

constructor TTextMessage.Create(aText: string;
  aDirection: TMessageDirection);
begin
  inherited Create(aDirection);
  FText := aText;
  FDataLength := Length(FText);
  FCode := MC_TextMessage;
end;

destructor TTextMessage.Destroy;
begin
  inherited Destroy;
end;

constructor TTextMessage.UnpackFromSocketStream(aStream: TStream;
  aDirection: TMessageDirection);
begin
  Create(aStream.ReadAnsiString, aDirection);
end;

constructor TTextMessage.LoadFromStream(aStream: TStream);
var
  mtext: string;
  dir: TMessageDirection;
  sen: boolean;
begin
  mtext := aStream.ReadAnsiString;
  dir := TMessageDirection(aStream.ReadByte);
  sen := boolean(aStream.ReadByte);

  self.Create(mtext,dir);
  FSended := sen;
  FTimeCreated := aStream.ReadQWord;
end;

procedure TTextMessage.PackToStream(aStream: TStream);
begin
  aStream.WriteByte(Ord(FCode)); // read in message list
  aStream.WriteAnsiString(FText);
  aStream.WriteByte(Ord(FDirection));
  aStream.WriteByte(Byte(FSended));
  aStream.WriteQWord(QWord(FTimeCreated));
end;

procedure TTextMessage.PackToSocketStream(aStream: TStream);
begin
  aStream.WriteAnsiString(FText);
end;

end.
