unit uJsonPath;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uJsonTypes, uJsonIndex, uFileHandler, uStringPool;

type
  { ── TJSONPathBuilder ─────────────────────────────────────────────
    Builds JSONPath expressions ($.data[0].name) by walking the
    parent chain from a node to the root. Reads key names from
    the file handler when needed.
  ─────────────────────────────────────────────────────────────────── }

  TJSONPathBuilder = class
  private
    FIndex: TJSONIndex;
    FFileHandler: TFileHandler;
    FStringPool: TStringPool;

    function ReadKey(const Entry: TJSONIndexEntry): string;
    function GetArrayPosition(ANodeIndex: Integer): Integer;
  public
    constructor Create(AIndex: TJSONIndex; AFileHandler: TFileHandler;
      AStringPool: TStringPool);

    { Build the full JSONPath for a node }
    function BuildPath(ANodeIndex: Integer): string;

    { Build a list of path segments (for breadcrumb display) }
    function BuildPathSegments(ANodeIndex: Integer): TStringList;
  end;

implementation

{ ── TJSONPathBuilder ─────────────────────────────────────────────── }

constructor TJSONPathBuilder.Create(AIndex: TJSONIndex;
  AFileHandler: TFileHandler; AStringPool: TStringPool);
begin
  inherited Create;
  FIndex := AIndex;
  FFileHandler := AFileHandler;
  FStringPool := AStringPool;
end;

function TJSONPathBuilder.ReadKey(const Entry: TJSONIndexEntry): string;
var
  Bytes: TBytes;
begin
  if Entry.KeyLength = 0 then
    Exit('');

  Bytes := FFileHandler.ReadBytes(Entry.KeyOffset, Entry.KeyLength);
  SetString(Result, PAnsiChar(@Bytes[0]), Length(Bytes));

  { Strip surrounding quotes }
  if (Length(Result) >= 2) and (Result[1] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);

  Result := FStringPool.Intern(Result);
end;

function TJSONPathBuilder.GetArrayPosition(ANodeIndex: Integer): Integer;
begin
  if (ANodeIndex < 0) or (ANodeIndex >= FIndex.Count) then
    Exit(-1);
  Result := FIndex.GetEntryPtr(ANodeIndex)^.ChildOrdinal;
end;

function TJSONPathBuilder.BuildPath(ANodeIndex: Integer): string;
var
  Segments: array of string;
  SegCount: Integer;
  Idx: Integer;
  Entry: TJSONIndexEntry;
  ParentEntry: TJSONIndexEntry;
  Key: string;
  ArrPos: Integer;
  I: Integer;
begin
  if (ANodeIndex < 0) or (ANodeIndex >= FIndex.Count) then
    Exit('$');

  SegCount := 0;
  Idx := ANodeIndex;

  while Idx >= 0 do
  begin
    Entry := FIndex[Idx];

    if Entry.ParentIndex < 0 then
    begin
      { Root node }
      Inc(SegCount);
      SetLength(Segments, SegCount);
      Segments[SegCount - 1] := '$';
      Break;
    end;

    ParentEntry := FIndex[Entry.ParentIndex];

    if ParentEntry.NodeType = jntArray then
    begin
      { Array element — use [n] notation }
      ArrPos := GetArrayPosition(Idx);
      Inc(SegCount);
      SetLength(Segments, SegCount);
      Segments[SegCount - 1] := Format('[%d]', [ArrPos]);
    end
    else if ParentEntry.NodeType = jntObject then
    begin
      { Object property — use key name }
      Key := ReadKey(Entry);
      Inc(SegCount);
      SetLength(Segments, SegCount);
      if Key <> '' then
        Segments[SegCount - 1] := Key
      else
        Segments[SegCount - 1] := '?';
    end
    else
    begin
      Inc(SegCount);
      SetLength(Segments, SegCount);
      Segments[SegCount - 1] := '?';
    end;

    Idx := Entry.ParentIndex;
  end;

  { Build path from segments (they are in reverse order) }
  Result := '';
  for I := SegCount - 1 downto 0 do
  begin
    if Segments[I] = '$' then
      Result := '$'
    else if (Length(Segments[I]) > 0) and (Segments[I][1] = '[') then
      Result := Result + Segments[I]
    else
      Result := Result + '.' + Segments[I];
  end;

  if Result = '' then
    Result := '$';
end;

function TJSONPathBuilder.BuildPathSegments(ANodeIndex: Integer): TStringList;
var
  Segments: array of string;
  SegCount: Integer;
  Idx: Integer;
  Entry: TJSONIndexEntry;
  ParentEntry: TJSONIndexEntry;
  Key: string;
  ArrPos: Integer;
  I: Integer;
begin
  Result := TStringList.Create;

  if (ANodeIndex < 0) or (ANodeIndex >= FIndex.Count) then
  begin
    Result.Add('$');
    Exit;
  end;

  SegCount := 0;
  Idx := ANodeIndex;

  while Idx >= 0 do
  begin
    Entry := FIndex[Idx];

    if Entry.ParentIndex < 0 then
    begin
      Inc(SegCount);
      SetLength(Segments, SegCount);
      Segments[SegCount - 1] := '$';
      Break;
    end;

    ParentEntry := FIndex[Entry.ParentIndex];
    if ParentEntry.NodeType = jntArray then
    begin
      ArrPos := GetArrayPosition(Idx);
      Inc(SegCount);
      SetLength(Segments, SegCount);
      Segments[SegCount - 1] := Format('[%d]', [ArrPos]);
    end
    else
    begin
      Key := ReadKey(Entry);
      Inc(SegCount);
      SetLength(Segments, SegCount);
      Segments[SegCount - 1] := Key;
    end;

    Idx := Entry.ParentIndex;
  end;

  { Add segments in reverse (root first) }
  for I := SegCount - 1 downto 0 do
    Result.Add(Segments[I]);
end;

end.
