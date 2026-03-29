unit uJsonIndex;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, uJsonTypes;

const
  INDEX_BLOCK_SHIFT = 16;
  INDEX_BLOCK_SIZE  = 1 shl INDEX_BLOCK_SHIFT; // 65536 entries per block
  INDEX_BLOCK_MASK  = INDEX_BLOCK_SIZE - 1;

type
  PJSONIndexEntryBlock = ^TJSONIndexEntryBlock;
  TJSONIndexEntryBlock = array[0..INDEX_BLOCK_SIZE-1] of TJSONIndexEntry;

  { ── TJSONIndex ───────────────────────────────────────────────────
    Stores a paged array of TJSONIndexEntry records representing the
    complete structure of a JSON document. Each node is identified by
    its integer index into this array. 
    Using blocks prevents massive contiguous memory allocations and OOMs.
  ─────────────────────────────────────────────────────────────────── }

  TJSONIndex = class
  private
    { Fixed size array of pointers to prevent reallocation during threaded parsing }
    FBlocks: array[0..16383] of PJSONIndexEntryBlock; // Supports up to 1,073,741,824 nodes
    FBlockCount: Integer;
    FCount: Integer;
    FCapacity: Integer;
    FRootIndex: Integer;
    
    { Sequential lookup cache for O(1) GetChildAt }
    FLastChildParent: Integer;
    FLastChildOrdinal: Integer;
    FLastChildIndex: Integer;

    procedure Grow;
    function GetEntry(Index: Integer): TJSONIndexEntry; inline;
    procedure SetEntry(Index: Integer; const AEntry: TJSONIndexEntry); inline;
  public
    constructor Create;
    destructor Destroy; override;

    { Add a new entry, returns its index }
    function AddEntry(const AEntry: TJSONIndexEntry): Integer;

    { Add an uninitialized entry and return pointer for direct fast writing }
    function AddUninitializedEntry: PJSONIndexEntry; inline;

    { Reserve capacity to avoid frequent reallocations }
    procedure Reserve(ACapacity: Integer);

    { Get children indices of a parent node }
    function GetChildIndices(ParentIndex: Integer): TIntegerDynArray;

    { Get the nth child of a parent }
    function GetChildAt(ParentIndex: Integer; ChildOrdinal: Integer): Integer;

    { Fast sequential child access }
    function GetFirstChild(ParentIndex: Integer): Integer;
    function GetNextSibling(NodeIndex: Integer): Integer;

    { Get the depth of a node by walking parent chain }
    function GetNodeDepth(NodeIndex: Integer): Integer;

    { Get direct pointer to an entry without bounds checks (for iteration) }
    function GetEntryPtr(Index: Integer): PJSONIndexEntry; inline;

    { Clear all entries }
    procedure Clear;

    { Properties }
    property Entries[Index: Integer]: TJSONIndexEntry read GetEntry write SetEntry; default;
    property Count: Integer read FCount;
    property RootIndex: Integer read FRootIndex write FRootIndex;
  end;

implementation

{ ── TJSONIndex ───────────────────────────────────────────────────── }

constructor TJSONIndex.Create;
begin
  inherited Create;
  FCount := 0;
  FCapacity := 0;
  FBlockCount := 0;
  FRootIndex := -1;
  FLastChildParent := -1;
  FLastChildOrdinal := -1;
  FLastChildIndex := -1;
  FillChar(FBlocks, SizeOf(FBlocks), 0);
end;

destructor TJSONIndex.Destroy;
var
  I: Integer;
begin
  for I := 0 to FBlockCount - 1 do
    if Assigned(FBlocks[I]) then
      FreeMem(FBlocks[I]);
  inherited Destroy;
end;

procedure TJSONIndex.Grow;
var
  NewCap: Integer;
begin
  if FCapacity = 0 then
    NewCap := INDEX_BLOCK_SIZE
  else
    NewCap := FCapacity + INDEX_BLOCK_SIZE;
  Reserve(NewCap);
end;

procedure TJSONIndex.Reserve(ACapacity: Integer);
var
  NewBlockCount, I: Integer;
begin
  if ACapacity > FCapacity then
  begin
    NewBlockCount := (ACapacity + INDEX_BLOCK_MASK) shr INDEX_BLOCK_SHIFT;
    if NewBlockCount > Length(FBlocks) then
      raise ERangeError.Create('JSON Index exceeds maximum supported node count (1 billion nodes)');
      
    if NewBlockCount > FBlockCount then
    begin
      for I := FBlockCount to NewBlockCount - 1 do
      begin
        GetMem(FBlocks[I], SizeOf(TJSONIndexEntryBlock));
        // FillChar(FBlocks[I]^, SizeOf(TJSONIndexEntryBlock), 0); // Optimization: skip zero-filling
      end;
      FBlockCount := NewBlockCount;
      FCapacity := FBlockCount * INDEX_BLOCK_SIZE;
    end;
  end;
end;

function TJSONIndex.GetEntryPtr(Index: Integer): PJSONIndexEntry; inline;
begin
  Result := @(FBlocks[Index shr INDEX_BLOCK_SHIFT]^[Index and INDEX_BLOCK_MASK]);
end;

function TJSONIndex.AddEntry(const AEntry: TJSONIndexEntry): Integer;
begin
  if FCount >= FCapacity then
    Grow;
  Result := FCount;
  FBlocks[FCount shr INDEX_BLOCK_SHIFT]^[FCount and INDEX_BLOCK_MASK] := AEntry;
  Inc(FCount);
end;

function TJSONIndex.AddUninitializedEntry: PJSONIndexEntry; inline;
begin
  if FCount >= FCapacity then
    Grow;
  Result := @(FBlocks[FCount shr INDEX_BLOCK_SHIFT]^[FCount and INDEX_BLOCK_MASK]);
  Inc(FCount);
end;

function TJSONIndex.GetEntry(Index: Integer): TJSONIndexEntry;
begin
  if (Index < 0) or (Index >= FCount) then
    raise ERangeError.CreateFmt('Index %d out of range [0..%d]', [Index, FCount - 1]);
  Result := FBlocks[Index shr INDEX_BLOCK_SHIFT]^[Index and INDEX_BLOCK_MASK];
end;

procedure TJSONIndex.SetEntry(Index: Integer; const AEntry: TJSONIndexEntry);
begin
  if (Index < 0) or (Index >= FCount) then
    raise ERangeError.CreateFmt('Index %d out of range [0..%d]', [Index, FCount - 1]);
  FBlocks[Index shr INDEX_BLOCK_SHIFT]^[Index and INDEX_BLOCK_MASK] := AEntry;
end;

function TJSONIndex.GetChildIndices(ParentIndex: Integer): TIntegerDynArray;
var
  Idx, Cnt, Found: Integer;
  Entry: TJSONIndexEntry;
begin
  Entry := GetEntry(ParentIndex);
  Cnt := Entry.ChildCount;
  if Cnt = 0 then
  begin
    Result := nil;
    Exit;
  end;

  SetLength(Result, Cnt);
  Found := 0;
  Idx := Entry.FirstChildIndex;
  
  while (Idx >= 0) and (Found < Cnt) do
  begin
    Result[Found] := Idx;
    Inc(Found);
    Idx := GetEntryPtr(Idx)^.NextSiblingIndex;
  end;

  if Found < Cnt then
    SetLength(Result, Found);
end;

function TJSONIndex.GetFirstChild(ParentIndex: Integer): Integer;
begin
  if (ParentIndex < 0) or (ParentIndex >= FCount) then
    Exit(-1);
  Result := GetEntryPtr(ParentIndex)^.FirstChildIndex;
end;

function TJSONIndex.GetNextSibling(NodeIndex: Integer): Integer;
begin
  if (NodeIndex < 0) or (NodeIndex >= FCount) then
    Exit(-1);
  Result := GetEntryPtr(NodeIndex)^.NextSiblingIndex;
end;

function TJSONIndex.GetChildAt(ParentIndex: Integer; ChildOrdinal: Integer): Integer;
var
  Idx, Found: Integer;
  Entry: TJSONIndexEntry;
begin
  Result := -1;
  Entry := GetEntry(ParentIndex);
  if (ChildOrdinal < 0) or (ChildOrdinal >= Entry.ChildCount) then
    Exit;

  if (ParentIndex = FLastChildParent) and (ChildOrdinal >= FLastChildOrdinal) and (FLastChildIndex >= 0) then
  begin
    Found := FLastChildOrdinal;
    Idx := FLastChildIndex;
  end
  else
  begin
    Found := 0;
    Idx := Entry.FirstChildIndex;
  end;

  while (Idx >= 0) do
  begin
    if Found = ChildOrdinal then
    begin
      FLastChildParent := ParentIndex;
      FLastChildOrdinal := ChildOrdinal;
      FLastChildIndex := Idx;
      Exit(Idx);
    end;
    Inc(Found);
    Idx := GetEntryPtr(Idx)^.NextSiblingIndex;
  end;
end;

function TJSONIndex.GetNodeDepth(NodeIndex: Integer): Integer;
var
  Idx: Integer;
begin
  Result := 0;
  Idx := NodeIndex;
  while (Idx >= 0) and (Idx < FCount) do
  begin
    if GetEntryPtr(Idx)^.ParentIndex < 0 then
      Break;
    Inc(Result);
    Idx := GetEntryPtr(Idx)^.ParentIndex;
  end;
end;

procedure TJSONIndex.Clear;
var
  I: Integer;
begin
  FCount := 0;
  FRootIndex := -1;
  FLastChildParent := -1;
  FLastChildOrdinal := -1;
  FLastChildIndex := -1;
  
  for I := 0 to FBlockCount - 1 do
  begin
    if Assigned(FBlocks[I]) then
    begin
      FreeMem(FBlocks[I]);
      FBlocks[I] := nil;
    end;
  end;
  FBlockCount := 0;
  FCapacity := 0;
end;

end.
