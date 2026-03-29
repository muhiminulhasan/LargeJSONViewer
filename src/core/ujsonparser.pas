unit uJsonParser;

{$mode objfpc}{$H+}
{$C-} // Assertions off
{$R-} // Range checking off
{$Q-} // Overflow checking off

interface

uses
  Classes, SysUtils, uJsonTypes, uJsonIndex, uFileHandler, uStringPool, usimd_scanner;

type
  { ── Parser State ─────────────────────────────────────────────────── }
  TParserState = (
    psExpectValue,        // Expecting any JSON value
    psInObject,           // Inside { }, expecting key or }
    psAfterObjectKey,     // After "key", expecting :
    psAfterObjectColon,   // After :, expecting value
    psAfterObjectValue,   // After value in object, expecting , or }
    psInArray,            // Inside [ ], expecting value or ]
    psAfterArrayValue,    // After value in array, expecting , or ]
    psDone,               // Parsing complete
    psError               // Parse error
  );

  { ── Parser Stack Frame ──────────────────────────────────────────── }
  TParserFrame = record
    State: TParserState;
    NodeIndex: Integer;     // Index of the container (object/array) node
    ChildCount: Integer;    // Number of children found so far
    FirstChildIdx: Integer; // Index of first child in this container
    LastChildIdx: Integer;  // Index of last child in container
  end;
  PParserFrame = ^TParserFrame;

  { ── TStreamingJSONParser ───────────────────────────────────────── }
  TStreamingJSONParser = class
  private
    FFileHandler: TFileHandler;
    FIndex: TJSONIndex;
    FStringPool: TStringPool;

    { Mapped Viewer State }
    FViewBase: PByte;
    FViewOffset: Int64;
    FViewSize: Int64;
    FCurr: PByte;
    FEnd: PByte;

    { Explicit stack }
    FStack: array of TParserFrame;
    FStackTop: Integer;
    FStackCapacity: Integer;

    { State }
    FTerminated: Boolean;
    FErrorMessage: string;
    FNodesCreated: Integer;
    FEncoding: TJSONEncoding;
    FCharStride: Integer;
    FCharOffset: Integer;

    { Progress }
    FOnProgress: TParseProgressCallback;
    FStartTime: QWord;
    FLastProgressUpdate: QWord;
    FNodeCountSinceLastProgress: Integer;

    { Key tracking }
    FCurrentKeyOffset: Int64;
    FCurrentKeyLength: UInt16;

    { Pointer Management }
    function AbsolutePos: Int64; inline;
    procedure Require(MinBytes: Integer); inline;
    function GetASCII(P: PByte): Byte; inline;
    function PeekChar: Byte; inline;
    function ReadChar: Byte; inline;
    function IsEOF: Boolean; inline;

    { Stack management }
    procedure PushFrame(AState: TParserState; ANodeIndex: Integer); inline;
    procedure PopFrame; inline;
    function CurrentFrame: PParserFrame; inline;

    { Parsing primitives }
    procedure SkipWhitespace; inline;
    procedure ParseValue(AParentIndex: Integer; ADepth: Integer);
    procedure ParseString(out AOffset: Int64; out ALength: UInt32);
    procedure ParseNumber(out AOffset: Int64; out ALength: UInt32);
    procedure ParseLiteral(const Expected: AnsiString; out AOffset: Int64; out ALength: UInt32);
    procedure ParseObject(ANodeIndex: Integer; ADepth: Integer);
    procedure ParseArray(ANodeIndex: Integer; ADepth: Integer);

    { Index entry creation }
    function CreateNode(AType: TJSONNodeType; AOffset: Int64; AParent: Integer;
      ADepth: Integer; AFileLength: UInt32 = 0): Integer; inline;

    { Error handling }
    procedure RaiseError(const Msg: string);
    procedure RaiseErrorAtCurrentPos(const Msg: string);

    { Progress reporting }
    procedure ReportProgress;
  public
    constructor Create(AFileHandler: TFileHandler; AIndex: TJSONIndex;
      AStringPool: TStringPool);
    destructor Destroy; override;

    { Parse the entire file and build the index }
    procedure Parse;

    { Cancel parsing }
    procedure Cancel;

    { Properties }
    property Terminated: Boolean read FTerminated;
    property ErrorMessage: string read FErrorMessage;
    property NodesCreated: Integer read FNodesCreated;
    property OnProgress: TParseProgressCallback read FOnProgress write FOnProgress;
  end;

implementation

uses
  Math;

const
  PROGRESS_INTERVAL_MS = 100; // Report progress every 100ms
  MAX_STACK_DEPTH = 65536;    // Maximum nesting depth

{ ── TStreamingJSONParser ─────────────────────────────────────────── }

constructor TStreamingJSONParser.Create(AFileHandler: TFileHandler;
  AIndex: TJSONIndex; AStringPool: TStringPool);
begin
  inherited Create;
  FFileHandler := AFileHandler;
  FIndex := AIndex;
  FStringPool := AStringPool;
  
  FViewBase := nil;
  FViewOffset := 0;
  FViewSize := 0;
  FCurr := nil;
  FEnd := nil;

  FStackCapacity := 256;
  SetLength(FStack, FStackCapacity);
  FStackTop := -1;

  FTerminated := False;
  FErrorMessage := '';
  FNodesCreated := 0;
  FEncoding := jeUTF8;
  FCharStride := 1;
  FCharOffset := 0;
end;

destructor TStreamingJSONParser.Destroy;
begin
  FStack := nil;
  inherited Destroy;
end;

{ ── Pointer Management ────────────────────────────────────────────── }

function TStreamingJSONParser.AbsolutePos: Int64; inline;
begin
  Result := FViewOffset + (PtrUInt(FCurr) - PtrUInt(FViewBase));
end;

procedure TStreamingJSONParser.Require(MinBytes: Integer);
var
  CurrAbsOffset: Int64;
begin
  if (PtrUInt(FEnd) - PtrUInt(FCurr)) >= UInt32(MinBytes) then
    Exit;

  CurrAbsOffset := AbsolutePos;
  if CurrAbsOffset + MinBytes > FFileHandler.FileSize then
    MinBytes := Integer(FFileHandler.FileSize - CurrAbsOffset);
    
  if MinBytes <= 0 then Exit;

  FFileHandler.RequireWindow(CurrAbsOffset, MinBytes);
  FFileHandler.GetCurrentView(FViewBase, FViewOffset, FViewSize);
  
  FCurr := FViewBase + (CurrAbsOffset - FViewOffset);
  FEnd := FViewBase + FViewSize;
end;

function TStreamingJSONParser.GetASCII(P: PByte): Byte; inline;
begin
  if FCharStride = 1 then
    Result := P^
  else
  begin
    if (P + (1 - FCharOffset))^ = 0 then
      Result := (P + FCharOffset)^
    else
      Result := 0; // Not an ASCII char
  end;
end;

function TStreamingJSONParser.PeekChar: Byte;
begin
  if FCurr >= FEnd then
  begin
    Require(FCharStride);
    if FCurr >= FEnd then Exit(0);
  end;
  Result := GetASCII(FCurr);
end;

function TStreamingJSONParser.ReadChar: Byte;
begin
  Result := PeekChar;
  if Result <> 0 then Inc(FCurr, FCharStride);
end;

function TStreamingJSONParser.IsEOF: Boolean;
begin
  Result := (FCurr >= FEnd) and (AbsolutePos >= FFileHandler.FileSize);
end;

{ ── Stack Management ─────────────────────────────────────────────── }

procedure TStreamingJSONParser.PushFrame(AState: TParserState; ANodeIndex: Integer); inline;
begin
  Inc(FStackTop);
  if FStackTop >= FStackCapacity then
  begin
    if FStackCapacity >= MAX_STACK_DEPTH then
      RaiseErrorAtCurrentPos(Format('Maximum nesting depth (%d) exceeded', [MAX_STACK_DEPTH]));
    FStackCapacity := FStackCapacity * 2;
    if FStackCapacity > MAX_STACK_DEPTH then
      FStackCapacity := MAX_STACK_DEPTH;
    SetLength(FStack, FStackCapacity);
  end;
  FStack[FStackTop].State := AState;
  FStack[FStackTop].NodeIndex := ANodeIndex;
  FStack[FStackTop].ChildCount := 0;
  FStack[FStackTop].FirstChildIdx := -1;
  FStack[FStackTop].LastChildIdx := -1;
end;

procedure TStreamingJSONParser.PopFrame; inline;
begin
  if FStackTop >= 0 then Dec(FStackTop);
end;

function TStreamingJSONParser.CurrentFrame: PParserFrame; inline;
begin
  if FStackTop >= 0 then Result := @FStack[FStackTop] else Result := nil;
end;

{ ── Whitespace & SIMD Utilities ──────────────────────────────────── }

procedure TStreamingJSONParser.SkipWhitespace;
var
  C: Byte;
begin
  // Fast inline check for minified JSON (no whitespace)
  if FCurr < FEnd then
  begin
    C := GetASCII(FCurr);
    if (C <> 32) and (C <> 10) and (C <> 13) and (C <> 9) then Exit;
  end;

  while True do
  begin
    case FEncoding of
      jeUTF8:    FCurr := FastSkipWhitespace(FCurr, FEnd);
      jeUTF16LE: FCurr := FastSkipWhitespace16LE(FCurr, FEnd);
      jeUTF16BE: FCurr := FastSkipWhitespace16BE(FCurr, FEnd);
    end;
    if FCurr < FEnd then Break; // hit non-whitespace
    if AbsolutePos >= FFileHandler.FileSize then Break; // EOF
    Require(8192); // fetch next window block
  end;
end;

{ ── Parse Entry Point ────────────────────────────────────────────── }

procedure TStreamingJSONParser.Parse;
begin
  InitSIMDScanner; // Ensure pointers map to hardware

  FStartTime := GetTickCount64;
  FLastProgressUpdate := FStartTime;

  FIndex.Clear;
  FNodesCreated := 0;
  FNodeCountSinceLastProgress := 0;
  FStackTop := -1;
  
  { Initialize first map }
  if FFileHandler.FileSize > FFileHandler.WindowSize then
    FFileHandler.RequireWindow(0, Integer(FFileHandler.WindowSize))
  else
    FFileHandler.RequireWindow(0, Integer(FFileHandler.FileSize));
  FFileHandler.GetCurrentView(FViewBase, FViewOffset, FViewSize);
  FCurr := FViewBase;
  FEnd := FViewBase + FViewSize;

  { Detect BOM and adjust encoding }
  FEncoding := jeUTF8;
  FCharStride := 1;
  FCharOffset := 0;

  Require(4);
  if (FEnd - FCurr >= 3) and (FCurr[0] = $EF) and (FCurr[1] = $BB) and (FCurr[2] = $BF) then
  begin
    Inc(FCurr, 3);
  end
  else if (FEnd - FCurr >= 2) and (FCurr[0] = $FF) and (FCurr[1] = $FE) then
  begin
    Inc(FCurr, 2);
    FEncoding := jeUTF16LE;
    FCharStride := 2;
    FCharOffset := 0;
  end
  else if (FEnd - FCurr >= 2) and (FCurr[0] = $FE) and (FCurr[1] = $FF) then
  begin
    Inc(FCurr, 2);
    FEncoding := jeUTF16BE;
    FCharStride := 2;
    FCharOffset := 1;
  end
  else if (FEnd - FCurr >= 4) then
  begin
    // Auto-detect BOM-less UTF-16 assuming the first char is ASCII (e.g. '{', '[', space)
    if (FCurr[0] <> 0) and (FCurr[1] = 0) and (FCurr[2] <> 0) and (FCurr[3] = 0) then
    begin
      FEncoding := jeUTF16LE;
      FCharStride := 2;
      FCharOffset := 0;
    end
    else if (FCurr[0] = 0) and (FCurr[1] <> 0) and (FCurr[2] = 0) and (FCurr[3] <> 0) then
    begin
      FEncoding := jeUTF16BE;
      FCharStride := 2;
      FCharOffset := 1;
    end;
  end;

  SkipWhitespace;
  if IsEOF then RaiseErrorAtCurrentPos('Empty JSON document');

  // Quick check if the file starts with a valid JSON character
  if not (PeekChar in [Byte('{'), Byte('['), Byte('"'), Byte('t'), Byte('f'), Byte('n'), Byte('-'), Byte('0')..Byte('9')]) then
    RaiseErrorAtCurrentPos('The document does not start with a valid JSON value');

  try
    FIndex.RootIndex := 0; // The first parsed value is always at index 0
    ParseValue(-1, 0);
  except
    on E: Exception do
    begin
      // If we encounter an error, we catch it here to keep the partially loaded JSON.
      // We also need to close any open nodes on the stack.
      FErrorMessage := E.Message;
      FTerminated := True;
      
      while FStackTop >= 0 do
      begin
        if FStack[FStackTop].NodeIndex >= 0 then
        begin
          with FIndex.GetEntryPtr(FStack[FStackTop].NodeIndex)^ do
          begin
            ChildCount := FStack[FStackTop].ChildCount;
            FirstChildIndex := FStack[FStackTop].FirstChildIdx;
            if ChildCount > 0 then Include(Flags, jnfHasChildren);
            // FileLength might be incomplete, but it's fine for fault tolerance
          end;
        end;
        PopFrame;
      end;
    end;
  end;
  
  ReportProgress;
end;

{ ── Value Parsing ────────────────────────────────────────────────── }

procedure TStreamingJSONParser.ParseValue(AParentIndex: Integer; ADepth: Integer);
var
  Ch: Byte;
  NodeIdx: Integer;
  ValOffset: Int64;
  ValLength: UInt32;
  StartOffset: Int64;
begin
  if FTerminated then Exit;

  SkipWhitespace;
  if FCurr >= FEnd then RaiseErrorAtCurrentPos('Unexpected end of input');

  Ch := GetASCII(FCurr);
  StartOffset := AbsolutePos;

  case Ch of
    Byte('{'):
    begin
      Inc(FCurr, FCharStride);
      NodeIdx := CreateNode(jntObject, StartOffset, AParentIndex, ADepth);
      ParseObject(NodeIdx, ADepth);
    end;

    Byte('['):
    begin
      Inc(FCurr, FCharStride);
      NodeIdx := CreateNode(jntArray, StartOffset, AParentIndex, ADepth);
      ParseArray(NodeIdx, ADepth);
    end;

    Byte('"'):
    begin
      ParseString(ValOffset, ValLength);
      CreateNode(jntString, ValOffset, AParentIndex, ADepth, ValLength);
    end;

    Byte('-'), Byte('0')..Byte('9'):
    begin
      ParseNumber(ValOffset, ValLength);
      CreateNode(jntNumber, ValOffset, AParentIndex, ADepth, ValLength);
    end;

    Byte('t'):
    begin
      ValOffset := StartOffset;
      if FEncoding = jeUTF8 then
      begin
        if (FEnd - FCurr) >= 4 then
        begin
          if PInteger(FCurr)^ <> $65757274 then // 'true'
            RaiseErrorAtCurrentPos('Unexpected literal');
          Inc(FCurr, 4);
          ValLength := 4;
        end else
          ParseLiteral('true', ValOffset, ValLength);
      end else
        ParseLiteral('true', ValOffset, ValLength);
      CreateNode(jntBoolean, ValOffset, AParentIndex, ADepth, ValLength);
    end;

    Byte('f'):
    begin
      ValOffset := StartOffset;
      if FEncoding = jeUTF8 then
      begin
        if (FEnd - FCurr) >= 5 then
        begin
          if (PInteger(FCurr)^ <> $736C6166) or ((FCurr + 4)^ <> $65) then // 'fals' + 'e'
            RaiseErrorAtCurrentPos('Unexpected literal');
          Inc(FCurr, 5);
          ValLength := 5;
        end else
          ParseLiteral('false', ValOffset, ValLength);
      end else
        ParseLiteral('false', ValOffset, ValLength);
      CreateNode(jntBoolean, ValOffset, AParentIndex, ADepth, ValLength);
    end;

    Byte('n'):
    begin
      ValOffset := StartOffset;
      if FEncoding = jeUTF8 then
      begin
        if (FEnd - FCurr) >= 4 then
        begin
          if PInteger(FCurr)^ <> $6C6C756E then // 'null'
            RaiseErrorAtCurrentPos('Unexpected literal');
          Inc(FCurr, 4);
          ValLength := 4;
        end else
          ParseLiteral('null', ValOffset, ValLength);
      end else
        ParseLiteral('null', ValOffset, ValLength);
      CreateNode(jntNull, ValOffset, AParentIndex, ADepth, ValLength);
    end;

  else
    RaiseError(Format('Unexpected character "%s" at offset %d',
      [Chr(Ch), AbsolutePos]));
  end;

  Inc(FNodeCountSinceLastProgress);
  if FNodeCountSinceLastProgress >= 16384 then
  begin
    FNodeCountSinceLastProgress := 0;
    if (GetTickCount64 - FLastProgressUpdate) >= PROGRESS_INTERVAL_MS then
      ReportProgress;
  end;
end;

{ ── Object Parsing ───────────────────────────────────────────────── }

procedure TStreamingJSONParser.ParseObject(ANodeIndex: Integer; ADepth: Integer);
var
  Ch: Byte;
  KeyOffset: Int64;
  KeyLen: UInt32;
  Frame: PParserFrame;
  Entry: PJSONIndexEntry;
begin
  PushFrame(psInObject, ANodeIndex);

  while not FTerminated do
  begin
    SkipWhitespace;
    if FCurr >= FEnd then RaiseErrorAtCurrentPos('Unexpected end of input in object');

    Ch := GetASCII(FCurr);
    if Ch = Byte('}') then
    begin
      Inc(FCurr, FCharStride);
      Frame := CurrentFrame;
      Entry := FIndex.GetEntryPtr(ANodeIndex);
      Entry^.ChildCount := Frame^.ChildCount;
      Entry^.FirstChildIndex := Frame^.FirstChildIdx;
      Entry^.FileLength := UInt32(AbsolutePos - Entry^.FileOffset);
      if Frame^.ChildCount > 0 then Include(Entry^.Flags, jnfHasChildren);
      PopFrame;
      Exit;
    end;

    if Ch <> Byte('"') then
      RaiseError(Format('Expected string key in object at offset %d', [AbsolutePos]));

    ParseString(KeyOffset, KeyLen);
    FCurrentKeyOffset := KeyOffset;
    FCurrentKeyLength := KeyLen;

    if (FCurr < FEnd) and (GetASCII(FCurr) = Byte(':')) then
      Inc(FCurr, FCharStride)
    else
    begin
      SkipWhitespace;
      if (FCurr >= FEnd) or (GetASCII(FCurr) <> Byte(':')) then
        RaiseError(Format('Expected ":" after object key at offset %d', [AbsolutePos]));
      Inc(FCurr, FCharStride);
    end;

    try
      ParseValue(ANodeIndex, ADepth + 1);
    except
      on E: Exception do
      begin
        // Skip invalid JSON and try to sync to the next ',' or '}'
        FTerminated := False; // Recover
        while not IsEOF do
        begin
          Ch := PeekChar;
          if (Ch = Byte(',')) or (Ch = Byte('}')) then Break;
          Inc(FCurr, FCharStride);
        end;
      end;
    end;

    FCurrentKeyOffset := 0;
    FCurrentKeyLength := 0;

    if FCurr < FEnd then
    begin
      Ch := GetASCII(FCurr);
      if Ch = Byte(',') then
      begin
        Inc(FCurr, FCharStride);
        Continue;
      end
      else if Ch = Byte('}') then
        Continue; // Next iteration will handle '}'
    end;

    SkipWhitespace;
    if FCurr >= FEnd then RaiseErrorAtCurrentPos('Unexpected end of input');
    Ch := GetASCII(FCurr);
    if Ch = Byte(',') then
      Inc(FCurr, FCharStride)
    else if Ch <> Byte('}') then
      RaiseError(Format('Expected "," or "}" in object at offset %d', [AbsolutePos]));
  end;
end;

{ ── Array Parsing ────────────────────────────────────────────────── }

procedure TStreamingJSONParser.ParseArray(ANodeIndex: Integer; ADepth: Integer);
var
  Ch: Byte;
  Frame: PParserFrame;
  Entry: PJSONIndexEntry;
begin
  PushFrame(psInArray, ANodeIndex);
  FCurrentKeyOffset := 0;
  FCurrentKeyLength := 0;

  SkipWhitespace;
  if FCurr >= FEnd then RaiseErrorAtCurrentPos('Unexpected end of input in array');
  if GetASCII(FCurr) = Byte(']') then
  begin
    Inc(FCurr, FCharStride);
    Entry := FIndex.GetEntryPtr(ANodeIndex);
    Entry^.ChildCount := 0;
    Entry^.FirstChildIndex := -1;
    Entry^.FileLength := UInt32(AbsolutePos - Entry^.FileOffset);
    PopFrame;
    Exit;
  end;

  while not FTerminated do
  begin
    try
      ParseValue(ANodeIndex, ADepth + 1);
    except
      on E: Exception do
      begin
        // Skip invalid JSON and try to sync to the next ',' or ']'
        FTerminated := False; // Recover
        while not IsEOF do
        begin
          Ch := PeekChar;
          if (Ch = Byte(',')) or (Ch = Byte(']')) then Break;
          Inc(FCurr, FCharStride);
        end;
      end;
    end;
    if FCurr < FEnd then
    begin
      Ch := GetASCII(FCurr);
      if Ch = Byte(',') then
      begin
        Inc(FCurr, FCharStride);
        Continue;
      end;
    end;

    SkipWhitespace;
    if FCurr >= FEnd then RaiseErrorAtCurrentPos('Unexpected end of array');

    Ch := GetASCII(FCurr);
    if Ch = Byte(',') then
    begin
      Inc(FCurr, FCharStride);
    end
    else if Ch = Byte(']') then
    begin
      Inc(FCurr, FCharStride);
      Frame := CurrentFrame;
      Entry := FIndex.GetEntryPtr(ANodeIndex);
      Entry^.ChildCount := Frame^.ChildCount;
      Entry^.FirstChildIndex := Frame^.FirstChildIdx;
      Entry^.FileLength := UInt32(AbsolutePos - Entry^.FileOffset);
      if Frame^.ChildCount > 0 then Include(Entry^.Flags, jnfHasChildren);
      PopFrame;
      Exit;
    end
    else
      RaiseError(Format('Expected "," or "]" in array at offset %d', [AbsolutePos]));
  end;
end;

{ ── Value Parsers ────────────────────────────────────────────────── }

procedure TStreamingJSONParser.ParseString(out AOffset: Int64; out ALength: UInt32);
var
  StartPos: Int64;
begin
  if (FCurr >= FEnd) or (GetASCII(FCurr) <> Byte('"')) then RaiseErrorAtCurrentPos('Expected opening quote');
  
  StartPos := AbsolutePos;
  AOffset := StartPos;
  Inc(FCurr, FCharStride); // skip opening

  while True do
  begin
    case FEncoding of
      jeUTF8:    FCurr := FastSkipString(FCurr, FEnd);
      jeUTF16LE: FCurr := FastSkipString16LE(FCurr, FEnd);
      jeUTF16BE: FCurr := FastSkipString16BE(FCurr, FEnd);
    end;
    
    if FCurr < FEnd then
    begin
      if GetASCII(FCurr) = Byte('"') then
      begin
        Inc(FCurr, FCharStride);
        ALength := UInt32(AbsolutePos - AOffset);
        Exit;
      end;
      
      if GetASCII(FCurr) = Byte('\') then
      begin
        if FEnd - FCurr >= 2 * FCharStride then
          Inc(FCurr, 2 * FCharStride)
        else
        begin
          Require(2 * FCharStride);
          Inc(FCurr, 2 * FCharStride);
        end;
      end else RaiseErrorAtCurrentPos('Invalid char inside string');
    end else
    begin
      if AbsolutePos >= FFileHandler.FileSize then 
        RaiseErrorAtCurrentPos('Unterminated string');
      Require(4096); // Load more of the string block
    end;
  end;
end;

procedure TStreamingJSONParser.ParseNumber(out AOffset: Int64; out ALength: UInt32);
var
  Ch: Byte;
begin
  AOffset := AbsolutePos;

  // Fast path: if we have enough bytes in the current buffer, avoid PeekChar/IsEOF overhead.
  // A valid JSON number is almost never longer than 64 bytes.
  if (FEnd - FCurr) > (64 * FCharStride) then
  begin
    if GetASCII(FCurr) = Byte('-') then Inc(FCurr, FCharStride);

    Ch := GetASCII(FCurr);
    if Ch = Byte('0') then Inc(FCurr, FCharStride)
    else if Ch in [Byte('1')..Byte('9')] then
    begin
      Inc(FCurr, FCharStride);
      while GetASCII(FCurr) in [Byte('0')..Byte('9')] do Inc(FCurr, FCharStride);
    end else RaiseErrorAtCurrentPos('Invalid number');

    if GetASCII(FCurr) = Byte('.') then
    begin
      Inc(FCurr, FCharStride);
      if not (GetASCII(FCurr) in [Byte('0')..Byte('9')]) then RaiseErrorAtCurrentPos('Expected digit after .');
      while GetASCII(FCurr) in [Byte('0')..Byte('9')] do Inc(FCurr, FCharStride);
    end;

    Ch := GetASCII(FCurr);
    if Ch in [Byte('e'), Byte('E')] then
    begin
      Inc(FCurr, FCharStride);
      Ch := GetASCII(FCurr);
      if Ch in [Byte('+'), Byte('-')] then Inc(FCurr, FCharStride);
      if not (GetASCII(FCurr) in [Byte('0')..Byte('9')]) then RaiseErrorAtCurrentPos('Expected digit in exponent');
      while GetASCII(FCurr) in [Byte('0')..Byte('9')] do Inc(FCurr, FCharStride);
    end;
  end
  else
  begin
    if PeekChar = Byte('-') then Inc(FCurr, FCharStride);

    if PeekChar = Byte('0') then Inc(FCurr, FCharStride)
    else if PeekChar in [Byte('1')..Byte('9')] then
    begin
      Inc(FCurr, FCharStride);
      while (not IsEOF) and (PeekChar in [Byte('0')..Byte('9')]) do Inc(FCurr, FCharStride);
    end else RaiseErrorAtCurrentPos('Invalid number');

    if (not IsEOF) and (PeekChar = Byte('.')) then
    begin
      Inc(FCurr, FCharStride);
      if IsEOF or not (PeekChar in [Byte('0')..Byte('9')]) then RaiseErrorAtCurrentPos('Expected digit after .');
      while (not IsEOF) and (PeekChar in [Byte('0')..Byte('9')]) do Inc(FCurr, FCharStride);
    end;

    if (not IsEOF) and (PeekChar in [Byte('e'), Byte('E')]) then
    begin
      Inc(FCurr, FCharStride);
      if (not IsEOF) and (PeekChar in [Byte('+'), Byte('-')]) then Inc(FCurr, FCharStride);
      if IsEOF or not (PeekChar in [Byte('0')..Byte('9')]) then RaiseErrorAtCurrentPos('Expected digit in exponent');
      while (not IsEOF) and (PeekChar in [Byte('0')..Byte('9')]) do Inc(FCurr, FCharStride);
    end;
  end;

  ALength := UInt32(AbsolutePos - AOffset);
end;

procedure TStreamingJSONParser.ParseLiteral(const Expected: AnsiString; out AOffset: Int64; out ALength: UInt32);
var
  I: Integer;
begin
  AOffset := AbsolutePos;
  
  if (FEnd - FCurr) >= Length(Expected) * FCharStride then
  begin
    for I := 1 to Length(Expected) do
    begin
      if GetASCII(FCurr) <> Byte(Expected[I]) then RaiseErrorAtCurrentPos('Unexpected literal');
      Inc(FCurr, FCharStride);
    end;
  end
  else
  begin
    Require(Length(Expected) * FCharStride);
    for I := 1 to Length(Expected) do
    begin
      if IsEOF or (ReadChar <> Byte(Expected[I])) then
        RaiseErrorAtCurrentPos('Unexpected literal');
    end;
  end;
  ALength := UInt32(AbsolutePos - AOffset);
end;

{ ── Node Creation ────────────────────────────────────────────────── }

function TStreamingJSONParser.CreateNode(AType: TJSONNodeType; AOffset: Int64;
  AParent: Integer; ADepth: Integer; AFileLength: UInt32): Integer; inline;
var
  EntryPtr: PJSONIndexEntry;
  PrevChild: PJSONIndexEntry;
begin
  Result := FIndex.Count;
  EntryPtr := FIndex.AddUninitializedEntry;
  
  EntryPtr^.FileOffset := AOffset;
  EntryPtr^.FileLength := AFileLength;
  EntryPtr^.ParentIndex := AParent;
  EntryPtr^.FirstChildIndex := -1;
  EntryPtr^.NextSiblingIndex := -1;
  EntryPtr^.ChildCount := 0;
  EntryPtr^.NodeType := AType;
  if ADepth > 255 then EntryPtr^.Depth := 255 else EntryPtr^.Depth := ADepth;
  EntryPtr^.Flags := [];
  EntryPtr^.KeyOffset := FCurrentKeyOffset;
  EntryPtr^.KeyLength := FCurrentKeyLength;
  
  if (AParent >= 0) and (FStackTop >= 0) then
  begin
    EntryPtr^.ChildOrdinal := FStack[FStackTop].ChildCount;
    if FStack[FStackTop].ChildCount = 0 then
      FStack[FStackTop].FirstChildIdx := Result
    else
    begin
      PrevChild := FIndex.GetEntryPtr(FStack[FStackTop].LastChildIdx);
      PrevChild^.NextSiblingIndex := Result;
    end;
    FStack[FStackTop].LastChildIdx := Result;
    Inc(FStack[FStackTop].ChildCount);
  end
  else
    EntryPtr^.ChildOrdinal := -1;

  Inc(FNodesCreated);
end;

{ ── Error Handling & Progress ────────────────────────────────────── }

procedure TStreamingJSONParser.RaiseError(const Msg: string);
begin
  FErrorMessage := 'JSON Parse Error: ' + Msg;
  FTerminated := True;
  raise Exception.Create(FErrorMessage);
end;

procedure TStreamingJSONParser.RaiseErrorAtCurrentPos(const Msg: string);
begin
  RaiseError(Format('%s at byte offset %d', [Msg, AbsolutePos]));
end;

procedure TStreamingJSONParser.ReportProgress;
var
  Info: TParseProgressInfo;
  RootEntry: PJSONIndexEntry;
begin
  if not Assigned(FOnProgress) then Exit;

  { Dynamically update the root node's child count so the UI can stream results }
  if (FIndex.RootIndex >= 0) and (FStackTop >= 0) and (FStack[0].NodeIndex = FIndex.RootIndex) then
  begin
    RootEntry := FIndex.GetEntryPtr(FIndex.RootIndex);
    RootEntry^.ChildCount := FStack[0].ChildCount;
    RootEntry^.FirstChildIndex := FStack[0].FirstChildIdx;
  end;

  Info.BytesProcessed := AbsolutePos;
  Info.TotalBytes := FFileHandler.FileSize;
  Info.NodesFound := FNodesCreated;
  Info.CurrentDepth := FStackTop + 1;
  Info.ElapsedMs := GetTickCount64 - FStartTime;
  if Info.TotalBytes > 0 then
    Info.Percentage := Info.BytesProcessed / Info.TotalBytes
  else Info.Percentage := 0;

  { Ensure percentage doesn't exceed 1.0 (100%) due to offsets }
  if Info.Percentage > 1.0 then
    Info.Percentage := 1.0;

  FOnProgress(Info);
  FLastProgressUpdate := GetTickCount64;
end;

procedure TStreamingJSONParser.Cancel;
begin
  FTerminated := True;
end;

end.
