unit uCache;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uJsonTypes;

const
  CACHE_BUCKET_COUNT = 8192;
  CACHE_BUCKET_MASK = CACHE_BUCKET_COUNT - 1;

type
  { ── Doubly-Linked List Node ──────────────────────────────────────── }

  PCacheNode = ^TCacheNode;
  TCacheNode = record
    Key: Integer;           // Node index
    Data: TJSONNodeData;    // Materialized node data
    EstimatedSize: Integer; // Estimated memory usage in bytes
    Prev: PCacheNode;
    Next: PCacheNode;
    HashNext: PCacheNode;   // Next in hash bucket
  end;

  { ── TNodeCache (LRU) ──────────────────────────────────────────── }

  TNodeCache = class
  private
    FBuckets: array[0..CACHE_BUCKET_COUNT - 1] of PCacheNode;
    FHead: PCacheNode;       // Most recently used
    FTail: PCacheNode;       // Least recently used
    FCount: Integer;
    FCurrentSize: Int64;     // Current estimated memory usage
    FMaxSize: Int64;         // Maximum allowed memory
    FHitCount: Int64;
    FMissCount: Int64;

    function FindNode(AKey: Integer): PCacheNode;
    procedure MoveToHead(Node: PCacheNode);
    procedure RemoveNode(Node: PCacheNode);
    procedure AddToHead(Node: PCacheNode);
    procedure EvictLRU;
    function EstimateNodeSize(const Data: TJSONNodeData): Integer;
  public
    constructor Create(AMaxSizeBytes: Int64 = DEFAULT_CACHE_SIZE_BYTES);
    destructor Destroy; override;

    function TryGet(ANodeIndex: Integer; out AData: TJSONNodeData): Boolean;
    procedure Put(ANodeIndex: Integer; const AData: TJSONNodeData);
    function Contains(ANodeIndex: Integer): Boolean;
    procedure Remove(ANodeIndex: Integer);
    procedure Clear;

    property Count: Integer read FCount;
    property CurrentSizeBytes: Int64 read FCurrentSize;
    property MaxSizeBytes: Int64 read FMaxSize write FMaxSize;
    property HitCount: Int64 read FHitCount;
    property MissCount: Int64 read FMissCount;

    function HitRate: Double;
  end;

implementation

{ ── TNodeCache ───────────────────────────────────────────────────── }

constructor TNodeCache.Create(AMaxSizeBytes: Int64);
begin
  inherited Create;
  FillChar(FBuckets, SizeOf(FBuckets), 0);
  FHead := nil;
  FTail := nil;
  FCount := 0;
  FCurrentSize := 0;
  FMaxSize := AMaxSizeBytes;
  FHitCount := 0;
  FMissCount := 0;
end;

destructor TNodeCache.Destroy;
begin
  Clear;
  inherited Destroy;
end;

function TNodeCache.FindNode(AKey: Integer): PCacheNode;
var
  BucketIdx: Integer;
  Node: PCacheNode;
begin
  BucketIdx := Cardinal(AKey) and CACHE_BUCKET_MASK;
  Node := FBuckets[BucketIdx];
  while Node <> nil do
  begin
    if Node^.Key = AKey then
      Exit(Node);
    Node := Node^.HashNext;
  end;
  Result := nil;
end;

function TNodeCache.EstimateNodeSize(const Data: TJSONNodeData): Integer;
begin
  Result := SizeOf(TCacheNode)
    + Length(Data.Key) * SizeOf(Char)
    + Length(Data.Value) * SizeOf(Char)
    + Length(Data.FullValue) * SizeOf(Char)
    + 64; 
end;

procedure TNodeCache.MoveToHead(Node: PCacheNode);
begin
  if Node = FHead then Exit;
  
  if Node^.Prev <> nil then
    Node^.Prev^.Next := Node^.Next
  else
    FHead := Node^.Next;

  if Node^.Next <> nil then
    Node^.Next^.Prev := Node^.Prev
  else
    FTail := Node^.Prev;

  Node^.Prev := nil;
  Node^.Next := nil;
  
  AddToHead(Node);
end;

procedure TNodeCache.RemoveNode(Node: PCacheNode);
var
  BucketIdx: Integer;
  PrevInBucket, CurrInBucket: PCacheNode;
begin
  // Remove from LRU list
  if Node^.Prev <> nil then
    Node^.Prev^.Next := Node^.Next
  else
    FHead := Node^.Next;

  if Node^.Next <> nil then
    Node^.Next^.Prev := Node^.Prev
  else
    FTail := Node^.Prev;

  // Remove from Hash Bucket
  BucketIdx := Cardinal(Node^.Key) and CACHE_BUCKET_MASK;
  CurrInBucket := FBuckets[BucketIdx];
  PrevInBucket := nil;
  while CurrInBucket <> nil do
  begin
    if CurrInBucket = Node then
    begin
      if PrevInBucket = nil then
        FBuckets[BucketIdx] := Node^.HashNext
      else
        PrevInBucket^.HashNext := Node^.HashNext;
      Break;
    end;
    PrevInBucket := CurrInBucket;
    CurrInBucket := CurrInBucket^.HashNext;
  end;
end;

procedure TNodeCache.AddToHead(Node: PCacheNode);
begin
  Node^.Next := FHead;
  Node^.Prev := nil;
  if FHead <> nil then
    FHead^.Prev := Node;
  FHead := Node;
  if FTail = nil then
    FTail := Node;
end;

procedure TNodeCache.EvictLRU;
var
  Victim: PCacheNode;
begin
  while (FCurrentSize > FMaxSize) and (FTail <> nil) do
  begin
    Victim := FTail;
    RemoveNode(Victim);
    Dec(FCurrentSize, Victim^.EstimatedSize);
    Dec(FCount);
    Dispose(Victim);
  end;
end;

function TNodeCache.TryGet(ANodeIndex: Integer; out AData: TJSONNodeData): Boolean;
var
  Node: PCacheNode;
begin
  Node := FindNode(ANodeIndex);
  if Node = nil then
  begin
    Inc(FMissCount);
    Result := False;
    Exit;
  end;

  AData := Node^.Data;
  MoveToHead(Node);
  Inc(FHitCount);
  Result := True;
end;

procedure TNodeCache.Put(ANodeIndex: Integer; const AData: TJSONNodeData);
var
  Node: PCacheNode;
  NodeSize: Integer;
  BucketIdx: Integer;
begin
  NodeSize := EstimateNodeSize(AData);
  Node := FindNode(ANodeIndex);

  if Node <> nil then
  begin
    Dec(FCurrentSize, Node^.EstimatedSize);
    Node^.Data := AData;
    Node^.EstimatedSize := NodeSize;
    Inc(FCurrentSize, NodeSize);
    MoveToHead(Node);
    
    if FCurrentSize > FMaxSize then EvictLRU;
    Exit;
  end;

  New(Node);
  Node^.Key := ANodeIndex;
  Node^.Data := AData;
  Node^.EstimatedSize := NodeSize;
  
  BucketIdx := Cardinal(ANodeIndex) and CACHE_BUCKET_MASK;
  Node^.HashNext := FBuckets[BucketIdx];
  FBuckets[BucketIdx] := Node;

  AddToHead(Node);
  
  Inc(FCount);
  Inc(FCurrentSize, NodeSize);

  if FCurrentSize > FMaxSize then
    EvictLRU;
end;

function TNodeCache.Contains(ANodeIndex: Integer): Boolean;
begin
  Result := FindNode(ANodeIndex) <> nil;
end;

procedure TNodeCache.Remove(ANodeIndex: Integer);
var
  Node: PCacheNode;
begin
  Node := FindNode(ANodeIndex);
  if Node <> nil then
  begin
    RemoveNode(Node);
    Dec(FCurrentSize, Node^.EstimatedSize);
    Dec(FCount);
    Dispose(Node);
  end;
end;

procedure TNodeCache.Clear;
var
  Node, NextNode: PCacheNode;
begin
  Node := FHead;
  while Node <> nil do
  begin
    NextNode := Node^.Next;
    Dispose(Node);
    Node := NextNode;
  end;

  FillChar(FBuckets, SizeOf(FBuckets), 0);
  FHead := nil;
  FTail := nil;
  FCount := 0;
  FCurrentSize := 0;
end;

function TNodeCache.HitRate: Double;
var
  Total: Int64;
begin
  Total := FHitCount + FMissCount;
  if Total = 0 then
    Result := 0
  else
    Result := (FHitCount / Total) * 100.0;
end;

end.