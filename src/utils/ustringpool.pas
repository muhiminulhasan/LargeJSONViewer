unit uStringPool;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs;

type
  PInternedString = ^string;

  { ── TStringPool ──────────────────────────────────────────────────
    Interns strings so that identical strings share a single memory
    allocation. Essential for JSON files with millions of objects
    sharing the same keys ("id", "name", "timestamp", etc.).

    Memory savings example:
      1M objects × "timestamp" (9 bytes) = 9 MB normally
      With pool: 9 bytes + 1M × pointer overhead ≈ 8 MB saved

    Thread-safety: NOT thread-safe. Use one pool per thread or
    protect with critical section externally.
  ─────────────────────────────────────────────────────────────────── }

  TStringPool = class
  private
    FMap: TFPHashList;
    FTotalSaved: Int64;     // Bytes saved by deduplication
    FHitCount: Integer;     // Cache hits
    FMissCount: Integer;    // Cache misses (new unique strings)
  public
    constructor Create;
    destructor Destroy; override;

    { Intern a string — returns the shared instance.
      If the string was already interned, returns the existing one. }
    function Intern(const S: string): string;

    { Check if a string is already interned }
    function Contains(const S: string): Boolean;

    { Statistics }
    property UniqueCount: Integer read FMissCount;
    property HitCount: Integer read FHitCount;
    property TotalBytesSaved: Int64 read FTotalSaved;

    { Clear all interned strings }
    procedure Clear;
  end;

implementation

{ ── TStringPool ─────────────────────────────────────────────────── }

constructor TStringPool.Create;
begin
  inherited Create;
  FMap := TFPHashList.Create;
  FTotalSaved := 0;
  FHitCount := 0;
  FMissCount := 0;
end;

destructor TStringPool.Destroy;
begin
  Clear;
  FMap.Free;
  inherited Destroy;
end;

function TStringPool.Intern(const S: string): string;
var
  Idx: Integer;
  Stored: PInternedString;
begin
  if S = '' then
    Exit('');

  { Check if already interned }
  Idx := FMap.FindIndexOf(S);
  if Idx >= 0 then
  begin
    { Hit — return the shared string }
    Inc(FHitCount);
    Inc(FTotalSaved, Length(S) * SizeOf(Char));
    Exit(PInternedString(FMap.Items[Idx])^);
  end;

  { Miss — add new string }
  Inc(FMissCount);
  New(Stored);
  Stored^ := S;
  FMap.Add(Stored^, Stored);
  Result := Stored^;
end;

function TStringPool.Contains(const S: string): Boolean;
begin
  Result := FMap.FindIndexOf(S) >= 0;
end;

procedure TStringPool.Clear;
var
  I: Integer;
begin
  for I := 0 to FMap.Count - 1 do
    Dispose(PInternedString(FMap.Items[I]));
  FMap.Clear;
  FTotalSaved := 0;
  FHitCount := 0;
  FMissCount := 0;
end;

end.
