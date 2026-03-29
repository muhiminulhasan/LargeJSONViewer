unit uSearchEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uJsonTypes, uJsonIndex, uFileHandler, uCache, uStringPool;

type
  { ── Search Mode ──────────────────────────────────────────────────── }

  TSearchMode = (
    smKeys,       // Search in keys only
    smValues,     // Search in values only
    smAll         // Search in both keys and values
  );

  { ── TSearchEngine ────────────────────────────────────────────────
    Searches through the JSON index for matching keys and values.
    Supports:
    - Plain text search (substring match)
    - Case-sensitive / case-insensitive
    - Key-only, value-only, or both
    - RegEx support (via TRegExpr — can be added later)
    - Result streaming via callback
    - Cancellation support

    For small files: iterates materialized nodes from cache/file
    For large files: can scan raw file bytes (future SIMD path)
  ─────────────────────────────────────────────────────────────────── }

  TSearchEngine = class
  private
    FIndex: TJSONIndex;
    FFileHandler: TFileHandler;
    FCache: TNodeCache;
    FStringPool: TStringPool;

    { Search state }
    FResults: TSearchResultArray;
    FResultCount: Integer;
    FCurrentResultIndex: Integer;
    FSearching: Boolean;
    FTerminated: Boolean;

    { Search parameters }
    FQuery: string;
    FNormalizedQuery: string;
    FSearchMode: TSearchMode;
    FCaseSensitive: Boolean;
    FUseRegEx: Boolean;

    { Callbacks }
    FOnResult: TSearchResultCallback;
    FOnSearchComplete: TNotifyEvent;

    function ReadNodeKey(ANodeIndex: Integer): string;
    function MatchesQuery(const AText: string): Integer; // Returns match pos or 0
    function NodeValueMatchPos(ANodeIndex: Integer): Integer;

    procedure AddResult(ANodeIndex: Integer; AMatchStart, AMatchLength: Integer;
      AMatchInKey: Boolean);
  public
    constructor Create(AIndex: TJSONIndex; AFileHandler: TFileHandler;
      ACache: TNodeCache; AStringPool: TStringPool);
    destructor Destroy; override;

    { Execute search across all indexed nodes }
    procedure Search(const AQuery: string; AMode: TSearchMode;
      ACaseSensitive: Boolean; AUseRegEx: Boolean);

    { Cancel active search }
    procedure Cancel;

    { Navigate results }
    function NextResult: Integer;      // Returns node index or -1
    function PreviousResult: Integer;  // Returns node index or -1
    function CurrentResult: Integer;   // Returns node index or -1

    { Get result info string }
    function GetResultInfo: string;

    { Clear results }
    procedure ClearResults;

    { Properties }
    property Results: TSearchResultArray read FResults;
    property ResultCount: Integer read FResultCount;
    property CurrentResultIdx: Integer read FCurrentResultIndex;
    property IsSearching: Boolean read FSearching;
    property OnResult: TSearchResultCallback read FOnResult write FOnResult;
    property OnSearchComplete: TNotifyEvent read FOnSearchComplete write FOnSearchComplete;
  end;

implementation

uses
  Math;

{ ── TSearchEngine ────────────────────────────────────────────────── }

constructor TSearchEngine.Create(AIndex: TJSONIndex; AFileHandler: TFileHandler;
  ACache: TNodeCache; AStringPool: TStringPool);
begin
  inherited Create;
  FIndex := AIndex;
  FFileHandler := AFileHandler;
  FCache := ACache;
  FStringPool := AStringPool;

  FResultCount := 0;
  FCurrentResultIndex := -1;
  FSearching := False;
  FTerminated := False;
end;

destructor TSearchEngine.Destroy;
begin
  FResults := nil;
  inherited Destroy;
end;

function TSearchEngine.ReadNodeKey(ANodeIndex: Integer): string;
var
  Entry: TJSONIndexEntry;
  Bytes: TBytes;
begin
  Entry := FIndex[ANodeIndex];
  if Entry.KeyLength = 0 then
    Exit('');

  Bytes := FFileHandler.ReadBytes(Entry.KeyOffset, Entry.KeyLength);
  SetString(Result, PAnsiChar(@Bytes[0]), Length(Bytes));

  { Strip surrounding quotes }
  if (Length(Result) >= 2) and (Result[1] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function TSearchEngine.MatchesQuery(const AText: string): Integer;
begin
  if AText = '' then
    Exit(0);

  if FCaseSensitive then
    Exit(Pos(FNormalizedQuery, AText));

  Result := Pos(FNormalizedQuery, LowerCase(AText));
end;

function TSearchEngine.NodeValueMatchPos(ANodeIndex: Integer): Integer;
var
  Entry: TJSONIndexEntry;
  Buffer: array[0..8191] of Byte;
  ReadAt, ReadNow: Integer;
  ChunkStr: string;
  PosInChunk: Integer;
begin
  Entry := FIndex[ANodeIndex];
  
  if Entry.NodeType in [jntObject, jntArray] then
    Exit(0);
    
  if Entry.FileLength = 0 then
    Exit(0);
    
  ReadAt := 0;
  
  if Entry.FileLength <= SizeOf(Buffer) then
  begin
    ReadNow := FFileHandler.ReadInto(Entry.FileOffset, @Buffer[0], Entry.FileLength);
    SetString(ChunkStr, PAnsiChar(@Buffer[0]), ReadNow);
    if (Entry.NodeType = jntString) and (Length(ChunkStr) >= 2) and (ChunkStr[1] = '"') then
      ChunkStr := Copy(ChunkStr, 2, Length(ChunkStr) - 2);
    Exit(MatchesQuery(ChunkStr));
  end;

  while ReadAt < Entry.FileLength do
  begin
    if Entry.FileLength - ReadAt > SizeOf(Buffer) then
      ReadNow := FFileHandler.ReadInto(Entry.FileOffset + ReadAt, @Buffer[0], SizeOf(Buffer))
    else
      ReadNow := FFileHandler.ReadInto(Entry.FileOffset + ReadAt, @Buffer[0], Entry.FileLength - ReadAt);
      
    SetString(ChunkStr, PAnsiChar(@Buffer[0]), ReadNow);
    
    // Simple handling of quotes for chunked string
    if (Entry.NodeType = jntString) and (ReadAt = 0) and (Length(ChunkStr) > 0) and (ChunkStr[1] = '"') then
      ChunkStr[1] := ' '; // Space out the quote so it doesn't match accidentally
      
    PosInChunk := MatchesQuery(ChunkStr);
    if PosInChunk > 0 then
      Exit(ReadAt + PosInChunk);
      
    // overlap by the length of the query to not miss matches across chunk boundaries
    if (ReadAt + ReadNow < Entry.FileLength) and (Length(FNormalizedQuery) > 1) then
      Inc(ReadAt, ReadNow - Length(FNormalizedQuery) + 1)
    else
      Inc(ReadAt, ReadNow);
  end;
  Result := 0;
end;

procedure TSearchEngine.AddResult(ANodeIndex: Integer;
  AMatchStart, AMatchLength: Integer; AMatchInKey: Boolean);
var
  SR: TSearchResult;
begin
  SR.NodeIndex := ANodeIndex;
  SR.MatchStart := AMatchStart;
  SR.MatchLength := AMatchLength;
  SR.MatchInKey := AMatchInKey;

  Inc(FResultCount);
  if FResultCount > Length(FResults) then
  begin
    if Length(FResults) = 0 then
      SetLength(FResults, 256)
    else
      SetLength(FResults, Length(FResults) * 2);
  end;
  FResults[FResultCount - 1] := SR;

  if Assigned(FOnResult) then
    FOnResult(SR);
end;

procedure TSearchEngine.Search(const AQuery: string; AMode: TSearchMode;
  ACaseSensitive: Boolean; AUseRegEx: Boolean);
var
  I: Integer;
  Key: string;
  MatchPos: Integer;
begin
  ClearResults;

  if AQuery = '' then
    Exit;

  FQuery := AQuery;
  FSearchMode := AMode;
  FCaseSensitive := ACaseSensitive;
  FUseRegEx := AUseRegEx;
  FSearching := True;
  FTerminated := False;

  if FCaseSensitive then
    FNormalizedQuery := FQuery
  else
    FNormalizedQuery := LowerCase(FQuery);

  try
    { Iterate all nodes in the index }
    for I := 0 to FIndex.Count - 1 do
    begin
      if FTerminated then
        Break;

      { Search in keys }
      if FSearchMode in [smKeys, smAll] then
      begin
        Key := ReadNodeKey(I);
        MatchPos := MatchesQuery(Key);
        if MatchPos > 0 then
          AddResult(I, MatchPos, Length(FQuery), True);
      end;

      { Search in values }
      if FSearchMode in [smValues, smAll] then
      begin
        MatchPos := NodeValueMatchPos(I);
        if MatchPos > 0 then
          AddResult(I, MatchPos, Length(FQuery), False);
      end;
    end;
  finally
    FSearching := False;
    if Assigned(FOnSearchComplete) then
      FOnSearchComplete(Self);
  end;
end;

procedure TSearchEngine.Cancel;
begin
  FTerminated := True;
end;

function TSearchEngine.NextResult: Integer;
begin
  if FResultCount = 0 then
    Exit(-1);

  Inc(FCurrentResultIndex);
  if FCurrentResultIndex >= FResultCount then
    FCurrentResultIndex := 0;

  Result := FResults[FCurrentResultIndex].NodeIndex;
end;

function TSearchEngine.PreviousResult: Integer;
begin
  if FResultCount = 0 then
    Exit(-1);

  Dec(FCurrentResultIndex);
  if FCurrentResultIndex < 0 then
    FCurrentResultIndex := FResultCount - 1;

  Result := FResults[FCurrentResultIndex].NodeIndex;
end;

function TSearchEngine.CurrentResult: Integer;
begin
  if (FResultCount = 0) or (FCurrentResultIndex < 0) then
    Exit(-1);
  Result := FResults[FCurrentResultIndex].NodeIndex;
end;

function TSearchEngine.GetResultInfo: string;
begin
  if FResultCount = 0 then
  begin
    if FQuery <> '' then
      Result := '0/0'
    else
      Result := '';
  end
  else
    Result := Format('%d/%s', [FCurrentResultIndex + 1, FormatFloat('#,##0', FResultCount)]);
end;

procedure TSearchEngine.ClearResults;
begin
  FResultCount := 0;
  FCurrentResultIndex := -1;
  FQuery := '';
  FTerminated := False;
  { Keep array allocated for reuse }
end;

end.
