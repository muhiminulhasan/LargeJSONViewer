unit uJsonTypes;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  SysUtils;

const
  { Version identifier for index file format }
  LAZJSON_INDEX_VERSION = 1;

  { Default buffer sizes }
  DEFAULT_PARSE_BUFFER_SIZE = 65536;   // 64KB parse buffer
  DEFAULT_MMAP_WINDOW_SIZE  = 268435456; // 256MB sliding window

  { File size tier thresholds (bytes) }
  TIER_SMALL_MAX    = 10 * 1024 * 1024;        // 10 MB
  TIER_MEDIUM_MAX   = 100 * 1024 * 1024;       // 100 MB
  TIER_LARGE_MAX    = 1024 * 1024 * 1024;      // 1 GB
  // Above TIER_LARGE_MAX = HUGE tier

  { Node cache defaults }
  DEFAULT_CACHE_SIZE_BYTES = 104857600; // 100 MB
  DEFAULT_MAX_DISPLAY_VALUE_LENGTH = 256; // Truncate display values

  { Search defaults }
  SEARCH_RESULT_BATCH_SIZE = 50;

type
  { ── JSON Value Types ─────────────────────────────────────────────── }

  TJSONNodeType = (
    jntObject,    // { ... }
    jntArray,     // [ ... ]
    jntString,    // "..."
    jntNumber,    // 123, -1.5e10
    jntBoolean,   // true / false
    jntNull       // null
  );

  { ── JSON Node Flags ──────────────────────────────────────────────── }

  TJSONNodeFlag = (
    jnfExpanded,       // Node is expanded in UI
    jnfChildrenLoaded, // Child index entries have been built
    jnfHasChildren,    // Node has at least one child
    jnfCached,         // Node data is in LRU cache
    jnfSearchMatch,    // Node matched a search query
    jnfBookmarked      // User bookmarked this node
  );
  TJSONNodeFlags = set of TJSONNodeFlag;

  { ── File Size Tier ───────────────────────────────────────────────── }

  TFileSizeTier = (
    fstSmall,     // < 10 MB   — full DOM
    fstMedium,    // 10–100 MB — DOM with lazy expansion
    fstLarge,     // 100 MB–1 GB — streaming + index
    fstHuge       // > 1 GB    — indexed streaming + disk cache
  );

  { ── JSON Encoding ────────────────────────────────────────────────── }

  TJSONEncoding = (
    jeUTF8,
    jeUTF16LE,
    jeUTF16BE
  );

  { ── JSON Index Entry ─────────────────────────────────────────────
    Compact record stored in a flat array for cache-friendly access.
    24 bytes per node keeps memory predictable:
      1M nodes = ~24 MB
      10M nodes = ~240 MB
  ─────────────────────────────────────────────────────────────────── }

  TJSONIndexEntry = packed record
    FileOffset:  Int64;          // Byte position of value start in file
    KeyOffset:   Int64;          // Byte position of key start (0 if none)
    FileLength:  UInt32;         // Byte length of the raw JSON value
    ParentIndex: Int32;          // Index of parent node (-1 for root)
    FirstChildIndex: Int32;      // Index of first child (-1 if leaf)
    NextSiblingIndex: Int32;     // Index of next sibling in same level (-1 if last)
    ChildCount:  Int32;          // Number of direct children
    ChildOrdinal: Int32;         // Index position within parent's children (0-based)
    KeyLength:   UInt16;         // Byte length of key string
    NodeType:    TJSONNodeType;  // Type of this node
    Depth:       UInt8;          // Nesting depth (capped at 255)
    Flags:       TJSONNodeFlags; // Runtime flags
    _Padding:    array[0..2] of Byte; // Pad to exactly 48 bytes for array alignment
  end;

  PJSONIndexEntry = ^TJSONIndexEntry;

  { Dynamic array of index entries }
  TJSONIndexEntryArray = array of TJSONIndexEntry;

  { ── Materialized Node Data ───────────────────────────────────────
    Created on-demand when a node becomes visible. Contains
    human-readable strings ready for display.
  ─────────────────────────────────────────────────────────────────── }

  TJSONNodeData = record
    Key:          string;          // Property name (empty for array items)
    Value:        string;          // Display value (may be truncated)
    FullValue:    string;          // Full value (for copy operations)
    FullValueLoaded: Boolean;      // True if FullValue has been loaded
    FileOffset:   Int64;           // Added for lazy loading
    FileLength:   UInt32;          // Added for lazy loading
    NodeType:     TJSONNodeType;   // Type of this node
    ChildCount:   Int32;           // Number of direct children
    Depth:        Integer;         // Depth in the tree
    ArrayIndex:   Integer;         // Ordinal position in parent array (-1 if none)
    NodeIndex:    Integer;         // Back-reference to the index array
    SizeBytes:    Int64;           // Byte length in original file
  end;

  PJSONNodeData = ^TJSONNodeData;

  { ── Parse Progress Info ──────────────────────────────────────────── }

  TParseProgressInfo = record
    BytesProcessed: Int64;
    TotalBytes:     Int64;
    NodesFound:     Integer;
    CurrentDepth:   Integer;
    ElapsedMs:      Int64;
    Percentage:     Double;
  end;

  { ── Search Result ────────────────────────────────────────────────── }

  TSearchResult = record
    NodeIndex:   Integer;         // Index into TJSONIndex
    MatchStart:  Integer;         // Character offset within value
    MatchLength: Integer;         // Length of match
    MatchInKey:  Boolean;         // True if match is in key, false if in value
  end;
  TSearchResultArray = array of TSearchResult;

  { ── Callbacks ────────────────────────────────────────────────────── }

  TParseProgressCallback = procedure(const Info: TParseProgressInfo) of object;
  TSearchResultCallback  = procedure(const Result: TSearchResult) of object;

{ ── Helper Functions ─────────────────────────────────────────────── }

function JSONNodeTypeToStr(AType: TJSONNodeType): string;
function DetectFileSizeTier(AFileSize: Int64): TFileSizeTier;
function FormatByteSize(ABytes: Int64): string;

implementation

function JSONNodeTypeToStr(AType: TJSONNodeType): string;
begin
  case AType of
    jntObject:  Result := 'Object';
    jntArray:   Result := 'Array';
    jntString:  Result := 'String';
    jntNumber:  Result := 'Number';
    jntBoolean: Result := 'Boolean';
    jntNull:    Result := 'Null';
  else
    Result := 'Unknown';
  end;
end;

function DetectFileSizeTier(AFileSize: Int64): TFileSizeTier;
begin
  if AFileSize <= TIER_SMALL_MAX then
    Result := fstSmall
  else if AFileSize <= TIER_MEDIUM_MAX then
    Result := fstMedium
  else if AFileSize <= TIER_LARGE_MAX then
    Result := fstLarge
  else
    Result := fstHuge;
end;

function FormatByteSize(ABytes: Int64): string;
const
  KB = 1024;
  MB = 1024 * KB;
  GB = Int64(1024) * MB;
begin
  if ABytes >= GB then
    Result := Format('%.2f GB', [ABytes / GB])
  else if ABytes >= MB then
    Result := Format('%.2f MB', [ABytes / MB])
  else if ABytes >= KB then
    Result := Format('%.2f KB', [ABytes / KB])
  else
    Result := Format('%d bytes', [ABytes]);
end;

end.
