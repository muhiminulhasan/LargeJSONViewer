unit uFileHandler;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows, uJsonTypes;

type
  { ── File Access Mode ─────────────────────────────────────────────── }

  TFileAccessMode = (
    famBuffered,       // TFileStream-based buffered reading (small files)
    famMemoryMapped,   // Memory-mapped file I/O (SSD large files)
    famStreamed        // Sliding window via ReadFile (HDD large files)
  );

  { ── TFileHandler ─────────────────────────────────────────────────
    Abstracts file access with two strategies:
      - Buffered: For small files (< 10 MB), loads entirely into memory
      - Memory-Mapped: For larger files, uses OS memory mapping with
        a sliding window for huge files (> 1 GB)

    Usage:
      Handler := TFileHandler.Create;
      try
        Handler.OpenFile('data.json');
        // Read bytes at any offset
        Bytes := Handler.ReadBytes(Offset, Count);
        // Or get raw pointer (mmap only, faster)
        P := Handler.GetPointer(Offset, Count);
      finally
        Handler.Free;
      end;
  ─────────────────────────────────────────────────────────────────── }

  TFileHandler = class
  private
    FFileName: string;
    FFileSize: Int64;
    FAccessMode: TFileAccessMode;
    FSizeTier: TFileSizeTier;
    FAllocationGranularity: DWORD;

    { Buffered mode fields }
    FBufferedData: TBytes;       // Entire file in memory (small files)

    { Memory-mapped mode fields }
    FFileHandle: THandle;
    FMappingHandle: THandle;
    FMapViewBase: Pointer;       // Base pointer to mapped region
    FMapViewOffset: Int64;       // Current window offset
    FMapViewSize: Int64;         // Current window size

    { Streamed mode fields (HDD) }
    FStreamBuffer: PByte;
    
    { Sliding window config }
    FWindowSize: Int64;          // Max window size (256MB default)

    procedure OpenBuffered;
    procedure OpenMemoryMapped;
    procedure OpenStreamed;
    procedure CloseBuffered;
    procedure CloseMemoryMapped;
    procedure CloseStreamed;
    procedure EnsureWindow(Offset: Int64; MinSize: Integer);
    procedure EnsureWindowStreamed(Offset: Int64; MinSize: Integer);
    function GetIsOpen: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    { Open a JSON file — auto-detects access mode based on size }
    procedure OpenFile(const AFileName: string);

    { Close the currently open file }
    procedure CloseFile;

    { Read bytes at the given offset. Safe for any access mode.
      Returns a copy of the data. }
    function ReadBytes(Offset: Int64; Count: Integer): TBytes;

    { Read bytes into an existing buffer. Returns actual bytes read. }
    function ReadInto(Offset: Int64; Buffer: PByte; Count: Integer): Integer;

    { Get a direct pointer to file data (mmap only).
      For buffered mode, returns pointer into FBufferedData.
      Caller must NOT free the pointer.
      The pointer is valid only until the next EnsureWindow call. }
    function GetPointer(Offset: Int64; Count: Integer): PByte;

    { Get the current mapped view bounds for fast external scanning }
    procedure GetCurrentView(out ABase: PByte; out AOffset: Int64; out ASize: Int64);

    { Request window at specific place to ensure we can scan (used by SIMD parser bounding check) }
    procedure RequireWindow(Offset: Int64; MinSize: Integer);

    { Read a single byte }
    function ReadByte(Offset: Int64): Byte;

    { Properties }
    property FileName: string read FFileName;
    property FileSize: Int64 read FFileSize;
    property AccessMode: TFileAccessMode read FAccessMode;
    property SizeTier: TFileSizeTier read FSizeTier;
    property IsOpen: Boolean read GetIsOpen;
    property WindowSize: Int64 read FWindowSize write FWindowSize;
  end;

implementation

{ ── Helper Functions ──────────────────────────────────────────────── }

type
  STORAGE_PROPERTY_QUERY = record
    PropertyId: DWORD;
    QueryType: DWORD;
    AdditionalParameters: array[0..0] of Byte;
  end;

  DEVICE_SEEK_PENALTY_DESCRIPTOR = record
    Version: DWORD;
    Size: DWORD;
    IncursSeekPenalty: Boolean;
  end;

  TMEMORYSTATUSEX = record
    dwLength: DWORD;
    dwMemoryLoad: DWORD;
    ullTotalPhys: UInt64;
    ullAvailPhys: UInt64;
    ullTotalPageFile: UInt64;
    ullAvailPageFile: UInt64;
    ullTotalVirtual: UInt64;
    ullAvailVirtual: UInt64;
    ullAvailExtendedVirtual: UInt64;
  end;

function GlobalMemoryStatusEx(lpBuffer: Pointer): BOOL; stdcall; external 'kernel32.dll';
function SetFilePointerEx(hFile: THandle; liDistanceToMove: Int64; lpNewFilePointer: PInt64; dwMoveMethod: DWORD): BOOL; stdcall; external 'kernel32.dll';

function IsDriveSSD(const AFileName: string): Boolean;
var
  DriveRoot: string;
  hDevice: THandle;
  Query: STORAGE_PROPERTY_QUERY;
  Descriptor: DEVICE_SEEK_PENALTY_DESCRIPTOR;
  BytesReturned: DWORD;
begin
  Result := False;
  if Length(AFileName) < 2 then Exit;
  if AFileName[2] = ':' then
    DriveRoot := '\\.\' + AFileName[1] + ':'
  else
    Exit; // Network or relative path - assume HDD for safety

  hDevice := CreateFile(PChar(DriveRoot), 0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  if hDevice <> INVALID_HANDLE_VALUE then
  try
    Query.PropertyId := 7; // StorageDeviceSeekPenaltyProperty
    Query.QueryType := 0;  // PropertyStandardQuery
    if DeviceIoControl(hDevice, $002D1400, @Query, SizeOf(Query), @Descriptor, SizeOf(Descriptor), BytesReturned, nil) then
    begin
      Result := not Descriptor.IncursSeekPenalty;
    end;
  finally
    CloseHandle(hDevice);
  end;
end;

function GetAvailableMemoryMB: Int64;
var
  MemStatus: TMEMORYSTATUSEX;
begin
  MemStatus.dwLength := SizeOf(MemStatus);
  if GlobalMemoryStatusEx(@MemStatus) then
    Result := MemStatus.ullAvailPhys div (1024 * 1024)
  else
    Result := 1024; // Default to 1GB if unknown
end;

{ ── TFileHandler ─────────────────────────────────────────────────── }

constructor TFileHandler.Create;
var
  SysInfo: TSystemInfo;
begin
  inherited Create;
  FFileHandle := INVALID_HANDLE_VALUE;
  FMappingHandle := 0;
  FMapViewBase := nil;
  FMapViewOffset := -1;
  FMapViewSize := 0;
  FStreamBuffer := nil;
  FWindowSize := DEFAULT_MMAP_WINDOW_SIZE;
  FFileSize := 0;
  FBufferedData := nil;
  GetSystemInfo(@SysInfo);
  FAllocationGranularity := SysInfo.dwAllocationGranularity;
end;

destructor TFileHandler.Destroy;
begin
  CloseFile;
  inherited Destroy;
end;

function TFileHandler.GetIsOpen: Boolean;
begin
  case FAccessMode of
    famBuffered:
      Result := Length(FBufferedData) > 0;
    famMemoryMapped:
      Result := FFileHandle <> INVALID_HANDLE_VALUE;
  else
    Result := False;
  end;
end;

procedure TFileHandler.OpenFile(const AFileName: string);
var
  SR: TSearchRec;
  AvailMemMB: Int64;
  IsSSD: Boolean;
begin
  CloseFile;
  FFileName := AFileName;

  { Get file size }
  if FindFirst(AFileName, faAnyFile, SR) = 0 then
  begin
    FFileSize := SR.Size;
    SysUtils.FindClose(SR);
  end
  else
    raise EFOpenError.CreateFmt('File not found: %s', [AFileName]);

  if FFileSize = 0 then
    raise EFOpenError.Create('File is empty');

  AvailMemMB := GetAvailableMemoryMB;
  IsSSD := IsDriveSSD(AFileName);

  { Determine window size based on available memory to prevent OOM }
  FWindowSize := 64 * 1024 * 1024; // 64MB default safe window
  if SizeOf(Pointer) = 8 then
  begin
    if (AvailMemMB > 2048) and (FFileSize <= 512 * 1024 * 1024) then
      FWindowSize := FFileSize // Map whole file up to 512MB if we have plenty of RAM
    else if AvailMemMB < 1024 then
      FWindowSize := 32 * 1024 * 1024; // Reduce window if memory is tight
  end
  else
  begin
    if AvailMemMB < 512 then
      FWindowSize := 16 * 1024 * 1024;
  end;

  { Determine tier and access mode }
  FSizeTier := DetectFileSizeTier(FFileSize);

  if FFileSize <= TIER_SMALL_MAX then
    FAccessMode := famBuffered
  else if IsSSD then
    FAccessMode := famMemoryMapped
  else
    FAccessMode := famStreamed; // HDD strategy

  case FAccessMode of
    famBuffered:     OpenBuffered;
    famMemoryMapped: OpenMemoryMapped;
    famStreamed:     OpenStreamed;
  end;
end;

procedure TFileHandler.CloseFile;
begin
  case FAccessMode of
    famBuffered:     CloseBuffered;
    famMemoryMapped: CloseMemoryMapped;
    famStreamed:     CloseStreamed;
  end;
  FFileName := '';
  FFileSize := 0;
end;

{ ── Buffered Mode ────────────────────────────────────────────────── }

procedure TFileHandler.OpenBuffered;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(FBufferedData, FFileSize);
    Stream.ReadBuffer(FBufferedData[0], FFileSize);
  finally
    Stream.Free;
  end;
end;

procedure TFileHandler.CloseBuffered;
begin
  FBufferedData := nil;
end;

{ ── Streamed Mode (HDD Optimized) ────────────────────────────────── }

procedure TFileHandler.OpenStreamed;
begin
  FFileHandle := CreateFileW(
    PWideChar(UnicodeString(FFileName)),
    GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN,
    0
  );

  if FFileHandle = INVALID_HANDLE_VALUE then
    raise EFOpenError.CreateFmt('Cannot open file: %s (Error: %d)',
      [FFileName, GetLastError]);

  GetMem(FStreamBuffer, FWindowSize);
  FMapViewBase := FStreamBuffer;
  FMapViewOffset := -1; // Force read
  EnsureWindowStreamed(0, 1024);
end;

procedure TFileHandler.CloseStreamed;
begin
  if FStreamBuffer <> nil then
  begin
    FreeMem(FStreamBuffer);
    FStreamBuffer := nil;
  end;
  if FFileHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FFileHandle);
    FFileHandle := INVALID_HANDLE_VALUE;
  end;
  FMapViewBase := nil;
end;

procedure TFileHandler.EnsureWindowStreamed(Offset: Int64; MinSize: Integer);
var
  BytesToRead: DWORD;
  BytesRead: DWORD;
  ReadOffset: Int64;
  MaxReadSize: Int64;
begin
  if (FStreamBuffer <> nil) and
     (Offset >= FMapViewOffset) and
     (Offset + MinSize <= FMapViewOffset + FMapViewSize) then
    Exit; // Already in buffer

  ReadOffset := Offset;
  
  MaxReadSize := FWindowSize;
  if ReadOffset + MaxReadSize > FFileSize then
    MaxReadSize := FFileSize - ReadOffset;
    
  if MaxReadSize < MinSize then
    MaxReadSize := MinSize; // Should not happen unless out of bounds

  // Reallocate if MinSize is larger than WindowSize
  if MaxReadSize > FWindowSize then
  begin
    FWindowSize := MaxReadSize;
    ReallocMem(FStreamBuffer, FWindowSize);
    FMapViewBase := FStreamBuffer;
  end;

  BytesToRead := DWORD(MaxReadSize);
  
  // Seek and Read
  SetFilePointerEx(FFileHandle, ReadOffset, nil, FILE_BEGIN);
  if not ReadFile(FFileHandle, FStreamBuffer^, BytesToRead, BytesRead, nil) then
    raise EFOpenError.CreateFmt('ReadFile failed at offset %d (Error: %d)', [ReadOffset, GetLastError]);
    
  FMapViewOffset := ReadOffset;
  FMapViewSize := BytesRead;
end;

{ ── Memory-Mapped Mode ───────────────────────────────────────────── }

procedure TFileHandler.OpenMemoryMapped;
begin
  { Open file with read-only access, but allow others to read and write to avoid locking }
  FFileHandle := CreateFileW(
    PWideChar(UnicodeString(FFileName)),
    GENERIC_READ,
    FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN,
    0
  );

  if FFileHandle = INVALID_HANDLE_VALUE then
    raise EFOpenError.CreateFmt('Cannot open file: %s (Error: %d)',
      [FFileName, GetLastError]);

  { Create file mapping }
  FMappingHandle := CreateFileMappingW(
    FFileHandle,
    nil,
    PAGE_READONLY,
    0,  // High-order DWORD of max size (0 = use file size)
    0,  // Low-order DWORD of max size
    nil // No name
  );

  if FMappingHandle = 0 then
  begin
    CloseHandle(FFileHandle);
    FFileHandle := INVALID_HANDLE_VALUE;
    raise EFOpenError.CreateFmt('Cannot create file mapping: %s (Error: %d)',
      [FFileName, GetLastError]);
  end;

  { Map initial window }
  FMapViewOffset := -1; // Force first EnsureWindow to map
  if FFileSize > FWindowSize then
    EnsureWindow(0, Integer(FWindowSize))
  else
    EnsureWindow(0, Integer(FFileSize));
end;

procedure TFileHandler.CloseMemoryMapped;
begin
  if FMapViewBase <> nil then
  begin
    UnmapViewOfFile(FMapViewBase);
    FMapViewBase := nil;
  end;
  if FMappingHandle <> 0 then
  begin
    CloseHandle(FMappingHandle);
    FMappingHandle := 0;
  end;
  if FFileHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FFileHandle);
    FFileHandle := INVALID_HANDLE_VALUE;
  end;
  FMapViewOffset := -1;
  FMapViewSize := 0;
end;

procedure TFileHandler.EnsureWindow(Offset: Int64; MinSize: Integer);
var
  AlignedOffset: Int64;
  ViewSize: Int64;
begin
  { Check if requested range is within current window }
  if (FMapViewBase <> nil) and
     (Offset >= FMapViewOffset) and
     (Offset + MinSize <= FMapViewOffset + FMapViewSize) then
    Exit; // Already mapped

  { Unmap previous view }
  if FMapViewBase <> nil then
  begin
    UnmapViewOfFile(FMapViewBase);
    FMapViewBase := nil;
  end;

  { Align offset DOWN to allocation granularity boundary }
  AlignedOffset := Offset and not (Int64(FAllocationGranularity) - 1);

  { Calculate view size — include the alignment adjustment }
  ViewSize := FWindowSize;
  if AlignedOffset + ViewSize > FFileSize then
    ViewSize := FFileSize - AlignedOffset;

  { Ensure minimum requested range is covered }
  if AlignedOffset + ViewSize < Offset + MinSize then
    ViewSize := Offset + MinSize - AlignedOffset;

  { Map the new view }
  FMapViewBase := MapViewOfFile(
    FMappingHandle,
    FILE_MAP_READ,
    DWord(AlignedOffset shr 32),   // High-order offset
    DWord(AlignedOffset and $FFFFFFFF), // Low-order offset
    ViewSize
  );

  if FMapViewBase = nil then
    raise EFOpenError.CreateFmt(
      'MapViewOfFile failed at offset %d, size %d (Error: %d)',
      [AlignedOffset, ViewSize, GetLastError]);

  FMapViewOffset := AlignedOffset;
  FMapViewSize := ViewSize;
end;

{ ── Read Operations ──────────────────────────────────────────────── }

function TFileHandler.ReadBytes(Offset: Int64; Count: Integer): TBytes;
begin
  if (Offset < 0) or (Offset >= FFileSize) then
    raise ERangeError.CreateFmt('Offset %d out of range [0..%d]',
      [Offset, FFileSize - 1]);

  { Clamp count to available data }
  if Offset + Count > FFileSize then
    Count := Integer(FFileSize - Offset);

  SetLength(Result, Count);
  if Count = 0 then
    Exit;

  case FAccessMode of
    famBuffered:
      Move(FBufferedData[Offset], Result[0], Count);
    famMemoryMapped:
    begin
      EnsureWindow(Offset, Count);
      Move(PByte(PtrUInt(FMapViewBase) + PtrUInt(Offset - FMapViewOffset))^,
           Result[0], Count);
    end;
    famStreamed:
    begin
      EnsureWindowStreamed(Offset, Count);
      Move(PByte(PtrUInt(FMapViewBase) + PtrUInt(Offset - FMapViewOffset))^,
           Result[0], Count);
    end;
  end;
end;

function TFileHandler.ReadInto(Offset: Int64; Buffer: PByte; Count: Integer): Integer;
begin
  if (Offset < 0) or (Offset >= FFileSize) or (Count <= 0) then
    Exit(0);

  { Clamp }
  if Offset + Count > FFileSize then
    Count := Integer(FFileSize - Offset);

  Result := Count;

  case FAccessMode of
    famBuffered:
      Move(FBufferedData[Offset], Buffer^, Count);
    famMemoryMapped:
    begin
      EnsureWindow(Offset, Count);
      Move(PByte(PtrUInt(FMapViewBase) + PtrUInt(Offset - FMapViewOffset))^,
           Buffer^, Count);
    end;
    famStreamed:
    begin
      EnsureWindowStreamed(Offset, Count);
      Move(PByte(PtrUInt(FMapViewBase) + PtrUInt(Offset - FMapViewOffset))^,
           Buffer^, Count);
    end;
  end;
end;

function TFileHandler.GetPointer(Offset: Int64; Count: Integer): PByte;
begin
  if (Offset < 0) or (Offset >= FFileSize) then
    raise ERangeError.CreateFmt('Offset %d out of range', [Offset]);

  if Offset + Count > FFileSize then
    Count := Integer(FFileSize - Offset);

  case FAccessMode of
    famBuffered:
      Result := @FBufferedData[Offset];
    famMemoryMapped:
    begin
      EnsureWindow(Offset, Count);
      Result := PByte(PtrUInt(FMapViewBase) + PtrUInt(Offset - FMapViewOffset));
    end;
    famStreamed:
    begin
      EnsureWindowStreamed(Offset, Count);
      Result := PByte(PtrUInt(FMapViewBase) + PtrUInt(Offset - FMapViewOffset));
    end;
  else
    Result := nil;
  end;
end;

procedure TFileHandler.RequireWindow(Offset: Int64; MinSize: Integer);
begin
  if FAccessMode = famMemoryMapped then
    EnsureWindow(Offset, MinSize)
  else if FAccessMode = famStreamed then
    EnsureWindowStreamed(Offset, MinSize);
  { For famBuffered, the entire file is already in memory, so no action needed }
end;

procedure TFileHandler.GetCurrentView(out ABase: PByte; out AOffset: Int64; out ASize: Int64);
begin
  if FAccessMode = famBuffered then
  begin
    ABase := @FBufferedData[0];
    AOffset := 0;
    ASize := FFileSize;
  end
  else
  begin
    ABase := PByte(FMapViewBase);
    AOffset := FMapViewOffset;
    ASize := FMapViewSize;
  end;
end;

function TFileHandler.ReadByte(Offset: Int64): Byte;
begin
  if (Offset < 0) or (Offset >= FFileSize) then
    raise ERangeError.CreateFmt('Offset %d out of range', [Offset]);

  case FAccessMode of
    famBuffered:
      Result := FBufferedData[Offset];
    famMemoryMapped:
    begin
      EnsureWindow(Offset, 1);
      Result := PByte(PtrUInt(FMapViewBase) + PtrUInt(Offset - FMapViewOffset))^;
    end;
    famStreamed:
    begin
      EnsureWindowStreamed(Offset, 1);
      Result := PByte(PtrUInt(FMapViewBase) + PtrUInt(Offset - FMapViewOffset))^;
    end;
  else
    Result := 0;
  end;
end;

end.
