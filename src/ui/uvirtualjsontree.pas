unit uVirtualJsonTree;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Controls, Graphics, Clipbrd, VirtualTrees,

  uJsonTypes, uJsonIndex, uFileHandler, uCache, uStringPool;


const
  // Maximum number of child nodes that will be shown directly under one parent
  // before the tree automatically groups them into ranges (e.g. “[0 … 999 999]”).
  // This prevents the control from freezing when an object/array contains
  // millions of children, while still allowing the user to drill into any range.
  MAX_NODES_PER_LEVEL = 1000000;

function BeautifyJSONString(const ARawJSON: string): string;

type
  PNodeDataRecord = ^TNodeDataRecord;
  TNodeDataRecord = record
    // Index of this node in the JSON index.
    // Used to look up the node in the index when needed.
    NodeIndex: Integer;
    ArrayIndex: Integer;
    IsGroup: Boolean;
    GroupStart: Integer;
    GroupCount: Integer;
    ParentJsonIdx: Integer;
    DisplayCaption: string;
    DisplayCaptionValid: Boolean;
  end;

  { ── TVirtualJSONTree ─────────────────────────────────────────────
    Wraps a TVirtualStringTree with virtual-style data model.
    Nodes are created perfectly lazily using VST's OnInitNode and OnInitChildren.
  ─────────────────────────────────────────────────────────────────── }

  TVirtualJSONTree = class
  private
    FTreeView: TVirtualStringTree;
    FIndex: TJSONIndex;
    FFileHandler: TFileHandler;
    FCache: TNodeCache;
    FStringPool: TStringPool;

    { Callbacks }
    FOnNodeSelected: TNotifyEvent;

    { State }
    FSelectedNodeIndex: Integer;
    FRootGrouped: Boolean;
    FParsingInProgress: Boolean;

    { TreeView event handlers }
    procedure TreeViewInitNode(Sender: TBaseVirtualTree; ParentNode, Node: PVirtualNode;
      var InitialStates: TVirtualNodeInitStates);
    procedure TreeViewInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode;
      var ChildCount: Cardinal);
    procedure TreeViewGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
      Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
    procedure TreeViewBeforeCellPaint(Sender: TBaseVirtualTree;
      TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
      CellPaintMode: TVTCellPaintMode; CellRect: TRect; var ContentRect: TRect);
    procedure TreeViewPaintText(Sender: TBaseVirtualTree; const TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType);
    procedure TreeViewAfterCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
      Node: PVirtualNode; Column: TColumnIndex; const CellRect: TRect);
    procedure TreeViewChange(Sender: TBaseVirtualTree; Node: PVirtualNode);

    { Data materialization }
    function MaterializeNode(ANodeIndex: Integer; AArrayIndex: Integer = -1): TJSONNodeData;
    function ReadStringFromFile(Offset: Int64; Length: Integer): string;

    { Display formatting }
    function FormatNodeCaption(const Data: TJSONNodeData; IsExpanded: Boolean): string;
    function FormatGroupCaption(AGroupStart, AGroupCount: Integer): string;
    function GetTypeColor(AType: TJSONNodeType): TColor;

  public
    constructor Create(ATreeView: TVirtualStringTree; AIndex: TJSONIndex;
      AFileHandler: TFileHandler; ACache: TNodeCache; AStringPool: TStringPool);
    destructor Destroy; override;

    { Build initial tree from root node }
    procedure BuildRootNodes;

    { Clear the tree }
    procedure Clear;

    { Collapse all expanded nodes }
    procedure CollapseAll;

    { Collapse node at current level }
    procedure CollapseCurrentLevel;

    { Expand node at current level }
    procedure ExpandCurrentLevel;

    { Navigate to a specific node index (expand path and select) }
    procedure NavigateToNode(ANodeIndex: Integer);

    { Get data for the currently selected node }
    function GetSelectedNodeData: TJSONNodeData;

    { Get the JSON path of the selected node }
    function GetSelectedNodePath: string;

    { Copy operations }
    procedure CopySelectedName;
    procedure CopySelectedValue;
    procedure CopySelectedPath;
    procedure CopySelectedSubtreeAsJSON(ABeautified: Boolean);

    { Refresh display }
    procedure RefreshNode(ANodeIndex: Integer);

    { Value loading }
    function GetNodeFullValue(var ANodeData: TJSONNodeData): string;

    { Update root node count dynamically during parsing }
    procedure UpdateRootCount;
    procedure SetParsingInProgress(AValue: Boolean);

    { Properties }
    property SelectedNodeIndex: Integer read FSelectedNodeIndex;
    property TreeView: TVirtualStringTree read FTreeView;
    property OnNodeSelected: TNotifyEvent read FOnNodeSelected write FOnNodeSelected;
    property ParsingInProgress: Boolean read FParsingInProgress write SetParsingInProgress;
  end;

implementation

uses
  Math
{$IFDEF MSWINDOWS}
  , UxTheme
{$ENDIF};

function BeautifyJSONString(const ARawJSON: string): string;
var
  OutputLength: Integer;
  OutputCapacity: Integer;
  Index: Integer;
  IndentLevel: Integer;
  InString: Boolean;
  EscapeNext: Boolean;
  CurrentChar: Char;
  Output: string;

  procedure EnsureCapacity(AAdditionalLength: Integer);
  begin
    if OutputLength + AAdditionalLength <= OutputCapacity then
      Exit;

    while OutputLength + AAdditionalLength > OutputCapacity do
      OutputCapacity := OutputCapacity * 2;

    SetLength(Output, OutputCapacity);
  end;

  procedure AppendChar(AValue: Char);
  begin
    EnsureCapacity(1);
    Inc(OutputLength);
    Output[OutputLength] := AValue;
  end;

  procedure AppendText(const AValue: string);
  begin
    if AValue = '' then
      Exit;

    EnsureCapacity(Length(AValue));
    Move(AValue[1], Output[OutputLength + 1], Length(AValue) * SizeOf(Char));
    Inc(OutputLength, Length(AValue));
  end;

  procedure AppendIndent;
  var
    IndentIndex: Integer;
  begin
    for IndentIndex := 1 to IndentLevel do
      AppendText('  ');
  end;

begin
  if ARawJSON = '' then
    Exit('');

  OutputCapacity := Length(ARawJSON) * 2;
  if OutputCapacity < 64 then
    OutputCapacity := 64;

  SetLength(Output, OutputCapacity);
  OutputLength := 0;
  IndentLevel := 0;
  InString := False;
  EscapeNext := False;

  for Index := 1 to Length(ARawJSON) do
  begin
    CurrentChar := ARawJSON[Index];

    if InString then
    begin
      AppendChar(CurrentChar);
      if EscapeNext then
        EscapeNext := False
      else if CurrentChar = '\' then
        EscapeNext := True
      else if CurrentChar = '"' then
        InString := False;
      Continue;
    end;

    case CurrentChar of
      '"':
        begin
          InString := True;
          AppendChar(CurrentChar);
        end;
      '{', '[':
        begin
          AppendChar(CurrentChar);
          Inc(IndentLevel);
          AppendText(LineEnding);
          AppendIndent;
        end;
      '}', ']':
        begin
          if OutputLength >= Length(LineEnding) + 1 then
          begin
            if Copy(Output, OutputLength - Length(LineEnding) + 1, Length(LineEnding)) = LineEnding then
              Dec(OutputLength, Length(LineEnding));
          end;

          while (OutputLength > 0) and (Output[OutputLength] = ' ') do
            Dec(OutputLength);

          if IndentLevel > 0 then
            Dec(IndentLevel);

          if (OutputLength > 0) and (Output[OutputLength] <> CurrentChar) and
             (Output[OutputLength] <> '{') and (Output[OutputLength] <> '[') then
          begin
            AppendText(LineEnding);
            AppendIndent;
          end;

          AppendChar(CurrentChar);
        end;
      ',':
        begin
          AppendChar(CurrentChar);
          AppendText(LineEnding);
          AppendIndent;
        end;
      ':':
        AppendText(': ');
      ' ', #9, #10, #13:
        ;
    else
      AppendChar(CurrentChar);
    end;
  end;

  SetLength(Output, OutputLength);
  Result := Output;
end;

{ ── TVirtualJSONTree ─────────────────────────────────────────────── }

constructor TVirtualJSONTree.Create(ATreeView: TVirtualStringTree; AIndex: TJSONIndex;
  AFileHandler: TFileHandler; ACache: TNodeCache; AStringPool: TStringPool);
begin
  inherited Create;
  FTreeView := ATreeView;
  FIndex := AIndex;
  FFileHandler := AFileHandler;
  FCache := ACache;
  FStringPool := AStringPool;
  FSelectedNodeIndex := -1;
  FRootGrouped := False;
  FParsingInProgress := False;

  { Wire up TreeView events }
  FTreeView.NodeDataSize := SizeOf(TNodeDataRecord);
  FTreeView.OnInitNode := @TreeViewInitNode;
  FTreeView.OnInitChildren := @TreeViewInitChildren;
  FTreeView.OnGetText := @TreeViewGetText;
  FTreeView.OnBeforeCellPaint := @TreeViewBeforeCellPaint;
  FTreeView.OnPaintText := @TreeViewPaintText;
  FTreeView.OnAfterCellPaint := @TreeViewAfterCellPaint;
  FTreeView.OnChange := @TreeViewChange;

  { Configure TreeOptions for classic rendering and performance }
  FTreeView.TreeOptions.PaintOptions := FTreeView.TreeOptions.PaintOptions - [toThemeAware, toUseExplorerTheme] + [toShowButtons, toShowTreeLines, toShowRoot, toAlwaysHideSelection, toHideFocusRect];
  
  // Keep toFullRowSelect so that keyboard navigation and mouse clicks highlight the whole row.
  // We completely disable VT's native selection drawing via toAlwaysHideSelection and
  // manually draw the full row selection background in OnBeforeCellPaint.
  FTreeView.TreeOptions.SelectionOptions := FTreeView.TreeOptions.SelectionOptions + [toFullRowSelect];
  
  // Disable default background drawing for selection to prevent the blue box
  FTreeView.Colors.FocusedSelectionColor := $00E1D5CD;
  FTreeView.Colors.FocusedSelectionBorderColor := $00E1D5CD;
  FTreeView.Colors.UnfocusedSelectionColor := $00E1D5CD;
  FTreeView.Colors.UnfocusedSelectionBorderColor := $00E1D5CD;
  FTreeView.Colors.SelectionRectangleBlendColor := $00E1D5CD;
  FTreeView.Colors.SelectionTextColor := clBlack;
  
  FTreeView.DefaultNodeHeight := 30;
end;

destructor TVirtualJSONTree.Destroy;
begin
  inherited Destroy;
end;

{ ── Data Materialization ─────────────────────────────────────────── }

function TVirtualJSONTree.MaterializeNode(ANodeIndex: Integer; AArrayIndex: Integer = -1): TJSONNodeData;
var
  Entry: TJSONIndexEntry;
  ParentEntry: TJSONIndexEntry;
  RawValue: string;
  RawKey: string;
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.NodeIndex := -1;

  if (ANodeIndex < 0) or (ANodeIndex >= FIndex.Count) then
    Exit;

  try
    { Check cache first }
    if FCache.TryGet(ANodeIndex, Result) then
      Exit;

    { Cache miss — read from file }
    Entry := FIndex[ANodeIndex];

    Result.NodeIndex := ANodeIndex;
    Result.NodeType := Entry.NodeType;
    Result.ChildCount := Entry.ChildCount;
    Result.Depth := Entry.Depth;
    Result.SizeBytes := Entry.FileLength;
    Result.FileOffset := Entry.FileOffset;
    Result.FileLength := Entry.FileLength;
    Result.FullValueLoaded := False;
    Result.FullValue := '';

    { Read key if present }
    if Entry.KeyLength > 0 then
    begin
      RawKey := ReadStringFromFile(Entry.KeyOffset, Entry.KeyLength);
      { Strip surrounding quotes and unescape }
      if (Length(RawKey) >= 2) and (RawKey[1] = '"') then
        RawKey := Copy(RawKey, 2, Length(RawKey) - 2);
      Result.Key := FStringPool.Intern(RawKey);
    end;

    { Determine array index if parent is array }
    Result.ArrayIndex := AArrayIndex;
    if (Result.ArrayIndex < 0) and (Entry.ParentIndex >= 0) and (Entry.ParentIndex < FIndex.Count) then
    begin
      ParentEntry := FIndex[Entry.ParentIndex];
      if ParentEntry.NodeType = jntArray then
      begin
        Result.ArrayIndex := Entry.ChildOrdinal;
      end;
    end;

    { Read value based on type }
    case Entry.NodeType of
      jntObject:
      begin
        Result.Value := Format('{...} (%d items)', [Entry.ChildCount]);
        Result.FullValueLoaded := True;
        Result.FullValue := Result.Value;
      end;
      jntArray:
      begin
        Result.Value := Format('[...] (%d items)', [Entry.ChildCount]);
        Result.FullValueLoaded := True;
        Result.FullValue := Result.Value;
      end;
      jntString:
      begin
        // Only load a preview for display to save memory and time
        if Entry.FileLength > UInt32(DEFAULT_MAX_DISPLAY_VALUE_LENGTH + 2) then
          RawValue := ReadStringFromFile(Entry.FileOffset, DEFAULT_MAX_DISPLAY_VALUE_LENGTH + 2)
        else
          RawValue := ReadStringFromFile(Entry.FileOffset, Integer(Entry.FileLength));
        
        { Strip surrounding quotes }
        if (Length(RawValue) >= 2) and (RawValue[1] = '"') then
          RawValue := Copy(RawValue, 2, Length(RawValue) - 2);
          
        { Truncate display value for performance }
        if Length(RawValue) > DEFAULT_MAX_DISPLAY_VALUE_LENGTH then
          Result.Value := Copy(RawValue, 1, DEFAULT_MAX_DISPLAY_VALUE_LENGTH) + '...'
        else
          Result.Value := RawValue;
      end;
      jntNumber, jntBoolean, jntNull:
      begin
        RawValue := ReadStringFromFile(Entry.FileOffset, Entry.FileLength);
        Result.Value := RawValue;
        Result.FullValue := RawValue;
        Result.FullValueLoaded := True;
      end;
    end;

    { Cache the result }
    FCache.Put(ANodeIndex, Result);
  except
    // Graceful fallback for access violations inside data reading
    Result.Value := '<Error reading node>';
    Result.FullValue := Result.Value;
    Result.FullValueLoaded := True;
  end;
end;

function TVirtualJSONTree.GetNodeFullValue(var ANodeData: TJSONNodeData): string;
begin
  if ANodeData.FullValueLoaded then
    Exit(ANodeData.FullValue);

  if ANodeData.NodeType = jntString then
  begin
    Result := ReadStringFromFile(ANodeData.FileOffset, ANodeData.FileLength);
    if (Length(Result) >= 2) and (Result[1] = '"') then
      Result := Copy(Result, 2, Length(Result) - 2);
    ANodeData.FullValue := Result;
    ANodeData.FullValueLoaded := True;
    
    // Update cache with full value if we loaded it
    FCache.Put(ANodeData.NodeIndex, ANodeData);
  end
  else
    Result := ANodeData.FullValue;
end;

function TVirtualJSONTree.ReadStringFromFile(Offset: Int64; Length: Integer): string;
var
  Bytes: TBytes;
begin
  if (Length <= 0) or (Offset < 0) then
    Exit('');

  { Clamp length to reasonable bounds for display }
  if Length > 1048576 then // 1MB max per read
    Length := 1048576;

  Bytes := FFileHandler.ReadBytes(Offset, Length);
  SetString(Result, PAnsiChar(@Bytes[0]), System.Length(Bytes));
end;

{ ── Display Formatting ───────────────────────────────────────────── }

function TVirtualJSONTree.FormatNodeCaption(const Data: TJSONNodeData; IsExpanded: Boolean): string;
var
  ValPart, KeyPart: string;
begin
  if IsExpanded and (Data.NodeType in [jntObject, jntArray]) then
  begin
    { If container is expanded, VirtualTree does not draw {...} or [...] next to the key }
    ValPart := '';
  end
  else
  begin
    case Data.NodeType of
      jntObject: ValPart := '';
      jntArray:  ValPart := '';
      jntString: ValPart := '"' + Data.Value + '"';
    else
      ValPart := Data.Value;
    end;
  end;

  if Data.Key <> '' then
    KeyPart := Data.Key + ': '
  else if Data.ArrayIndex >= 0 then
    KeyPart := Format('[%d]: ', [Data.ArrayIndex])
  else
    KeyPart := '';

  Result := KeyPart + ValPart;
end;

function TVirtualJSONTree.GetTypeColor(AType: TJSONNodeType): TColor;
begin
  case AType of
    jntObject:  Result := clBlack;
    jntArray:   Result := clBlack;
    jntString:  Result := $00A57744; // VirtualTree green/blue
    jntNumber:  Result := $001BAE00; // VirtualTree bright green
    jntBoolean: Result := clBlue;
    jntNull:    Result := clGray;
  else
    Result := clBlack;
  end;
end;

function TVirtualJSONTree.FormatGroupCaption(AGroupStart, AGroupCount: Integer): string;
var
  GroupEnd: Integer;
begin
  GroupEnd := AGroupStart + AGroupCount - 1;
  Result := Format('[%d ... %d]', [AGroupStart, GroupEnd]);

  if FParsingInProgress and (AGroupCount < MAX_NODES_PER_LEVEL) then
    Result := Result + ' (loaded so far)';
end;

{ ── Tree Population ──────────────────────────────────────────────── }

procedure TVirtualJSONTree.BuildRootNodes;
var
  RootEntry: TJSONIndexEntry;
begin
  FTreeView.BeginUpdate;
  try
    FTreeView.Clear;
    
    if (FIndex.Count = 0) or (FIndex.RootIndex < 0) then
      Exit;

    RootEntry := FIndex[FIndex.RootIndex];
    FRootGrouped := RootEntry.ChildCount > MAX_NODES_PER_LEVEL;
    
    { Map JSON root children directly to VirtualTree root nodes }
    if FRootGrouped then
      FTreeView.RootNodeCount := (RootEntry.ChildCount + MAX_NODES_PER_LEVEL - 1) div MAX_NODES_PER_LEVEL
    else
      FTreeView.RootNodeCount := RootEntry.ChildCount;
  finally
    FTreeView.EndUpdate;
  end;
end;

procedure TVirtualJSONTree.UpdateRootCount;
var
  RootEntry: TJSONIndexEntry;
  NewCount: Cardinal;
  ShouldGroup: Boolean;
begin
  if (FIndex.Count = 0) or (FIndex.RootIndex < 0) then
    Exit;

  RootEntry := FIndex[FIndex.RootIndex];
  ShouldGroup := RootEntry.ChildCount > MAX_NODES_PER_LEVEL;
  
  if ShouldGroup <> FRootGrouped then
  begin
    BuildRootNodes;
    Exit;
  end;

  if ShouldGroup then
    NewCount := (RootEntry.ChildCount + MAX_NODES_PER_LEVEL - 1) div MAX_NODES_PER_LEVEL
  else
    NewCount := RootEntry.ChildCount;

  if FTreeView.RootNodeCount <> NewCount then
    FTreeView.RootNodeCount := NewCount;
end;

{ ── TreeView Event Handlers ──────────────────────────────────────── }

procedure TVirtualJSONTree.TreeViewInitNode(Sender: TBaseVirtualTree; ParentNode, Node: PVirtualNode;
  var InitialStates: TVirtualNodeInitStates);
var
  Data, ParentData: PNodeDataRecord;
  Entry: TJSONIndexEntry;
  ParentJsonNodeIdx: Integer;
  ChildCount: Integer;
begin
  try
    Data := Sender.GetNodeData(Node);
    if not Assigned(Data) then Exit;

    Data^.IsGroup := False;
    Data^.GroupStart := 0;
    Data^.GroupCount := 0;
    Data^.DisplayCaptionValid := False;

    if ParentNode = nil then
    begin
      ParentJsonNodeIdx := FIndex.RootIndex;
      if ParentJsonNodeIdx < 0 then Exit;
      ChildCount := FIndex[ParentJsonNodeIdx].ChildCount;

      if ChildCount > MAX_NODES_PER_LEVEL then
      begin
        Data^.IsGroup := True;
        Data^.GroupStart := Node^.Index * MAX_NODES_PER_LEVEL;
        if Data^.GroupStart + MAX_NODES_PER_LEVEL > ChildCount then
          Data^.GroupCount := ChildCount - Data^.GroupStart
        else
          Data^.GroupCount := MAX_NODES_PER_LEVEL;

        Data^.ParentJsonIdx := ParentJsonNodeIdx;
        Data^.NodeIndex := -1;
        Data^.ArrayIndex := -1;

        InitialStates := InitialStates + [ivsHasChildren];
        Exit;
      end
      else
      begin
        Data^.ParentJsonIdx := ParentJsonNodeIdx;
        Data^.ArrayIndex := Node^.Index;
        Data^.NodeIndex := FIndex.GetChildAt(ParentJsonNodeIdx, Node^.Index);
      end;
    end
    else
    begin
      ParentData := Sender.GetNodeData(ParentNode);
      if not Assigned(ParentData) then Exit;

      if ParentData^.IsGroup then
      begin
        Data^.IsGroup := False;
        Data^.ParentJsonIdx := ParentData^.ParentJsonIdx;
        Data^.ArrayIndex := ParentData^.GroupStart + Node^.Index;
        Data^.NodeIndex := FIndex.GetChildAt(Data^.ParentJsonIdx, Data^.ArrayIndex);
      end
      else
      begin
        ParentJsonNodeIdx := ParentData^.NodeIndex;
        if ParentJsonNodeIdx < 0 then Exit;

        ChildCount := FIndex[ParentJsonNodeIdx].ChildCount;

        if ChildCount > MAX_NODES_PER_LEVEL then
        begin
          Data^.IsGroup := True;
          Data^.GroupStart := Node^.Index * MAX_NODES_PER_LEVEL;
          if Data^.GroupStart + MAX_NODES_PER_LEVEL > ChildCount then
            Data^.GroupCount := ChildCount - Data^.GroupStart
          else
            Data^.GroupCount := MAX_NODES_PER_LEVEL;

          Data^.ParentJsonIdx := ParentJsonNodeIdx;
          Data^.NodeIndex := -1;
          Data^.ArrayIndex := -1;

          InitialStates := InitialStates + [ivsHasChildren];
          Exit;
        end
        else
        begin
          Data^.ParentJsonIdx := ParentJsonNodeIdx;
          Data^.ArrayIndex := Node^.Index;
          Data^.NodeIndex := FIndex.GetChildAt(ParentJsonNodeIdx, Node^.Index);
        end;
      end;
    end;

    if (Data^.NodeIndex >= 0) and (Data^.NodeIndex < FIndex.Count) then
    begin
      Entry := FIndex[Data^.NodeIndex];
      if (Entry.NodeType in [jntObject, jntArray]) and (Entry.ChildCount > 0) then
      begin
        InitialStates := InitialStates + [ivsHasChildren];
        // Ensure root level items show their +/- button
        if ParentNode = nil then
          FTreeView.HasChildren[Node] := True;
      end;
    end;
  except
    // Swallow exceptions silently during tree rendering to avoid crash
  end;
end;

procedure TVirtualJSONTree.TreeViewInitChildren(Sender: TBaseVirtualTree; Node: PVirtualNode;
  var ChildCount: Cardinal);
var
  Data: PNodeDataRecord;
  Entry: TJSONIndexEntry;
begin
  ChildCount := 0;
  try
    Data := Sender.GetNodeData(Node);
    if not Assigned(Data) then Exit;

    if Data^.IsGroup then
    begin
      ChildCount := Data^.GroupCount;
    end
    else if (Data^.NodeIndex >= 0) and (Data^.NodeIndex < FIndex.Count) then
    begin
      Entry := FIndex[Data^.NodeIndex];
      
      if Entry.ChildCount > MAX_NODES_PER_LEVEL then
        ChildCount := (Entry.ChildCount + MAX_NODES_PER_LEVEL - 1) div MAX_NODES_PER_LEVEL
      else
        ChildCount := Entry.ChildCount;
    end;
  except
    ChildCount := 0;
  end;
end;

procedure TVirtualJSONTree.TreeViewGetText(Sender: TBaseVirtualTree; Node: PVirtualNode;
  Column: TColumnIndex; TextType: TVSTTextType; var CellText: String);
var
  Data: PNodeDataRecord;
  NodeData: TJSONNodeData;
begin
  CellText := '';
  try
    Data := Sender.GetNodeData(Node);
    if not Assigned(Data) then Exit;

    if Data^.IsGroup then
    begin
      CellText := FormatGroupCaption(Data^.GroupStart, Data^.GroupCount);
      Exit;
    end;

    if (Data^.NodeIndex < 0) or (Data^.NodeIndex >= FIndex.Count) then Exit;
    
    NodeData := MaterializeNode(Data^.NodeIndex, Data^.ArrayIndex);
    
    // We handle custom drawing in OnPaintText entirely, so we don't want VirtualTree
    // to draw the default text which would overlap.
    // However, we must return SOME text here so that the node gets the correct width
    // for scrolling.
    // Instead of full text, just return spaces so it has width but doesn't render dark black over our text
    if not Data^.DisplayCaptionValid then
    begin
      Data^.DisplayCaption := FormatNodeCaption(NodeData, Sender.Expanded[Node]);
      Data^.DisplayCaptionValid := True;
    end;
    CellText := StringOfChar(' ', Length(Data^.DisplayCaption));
  except
    CellText := 'Error reading node';
  end;
end;

procedure TVirtualJSONTree.TreeViewBeforeCellPaint(Sender: TBaseVirtualTree;
  TargetCanvas: TCanvas; Node: PVirtualNode; Column: TColumnIndex;
  CellPaintMode: TVTCellPaintMode; CellRect: TRect; var ContentRect: TRect);
begin
  try
    if not Assigned(Node) then Exit;

    // We draw the selection color across the entire width of the cell
    if vsSelected in Node^.States then
    begin
      TargetCanvas.Brush.Color := $00E1D5CD; // VirtualTree-like light gray/blue selection
      TargetCanvas.Font.Color := clBlack; // Prevent Windows from making text white on blue
    end
    else if (Node^.Index mod 2) = 1 then
      TargetCanvas.Brush.Color := $00F9F9F9  // Very light gray
    else
      TargetCanvas.Brush.Color := clWhite;

    // Draw the background
    TargetCanvas.Brush.Style := bsSolid;
    TargetCanvas.FillRect(CellRect);
  except
    // Ignore paint errors
  end;
end;

procedure TVirtualJSONTree.TreeViewPaintText(Sender: TBaseVirtualTree; const TargetCanvas: TCanvas;
  Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType);
var
  Data: PNodeDataRecord;
  NodeData: TJSONNodeData;
begin
  try
    Data := Sender.GetNodeData(Node);
    if not Assigned(Data) then Exit;
    
    if Data^.IsGroup then
    begin
      TargetCanvas.Font.Color := clTeal;
      TargetCanvas.Font.Style := [fsItalic];
      Exit;
    end;

    if (Data^.NodeIndex >= 0) and (Data^.NodeIndex < FIndex.Count) then
    begin
      // We will override standard text drawing in a different event, or just color it here.
      // But VirtualTree colorizes keys differently from values.
      // VirtualTree OnPaintText only allows changing font properties for the whole node string.
      // To get VirtualTree-style multi-colored text (e.g. green key, blue value),
      // we need to use OnBeforeCellPaint and draw it ourselves, or OnAfterCellPaint.
      // Since you already had some drawing code in your previous backup, we will use OnAfterCellPaint.
      // For now, let's just let it draw black.
      TargetCanvas.Font.Color := clBlack;
      TargetCanvas.Font.Style := [];
    end;
  except
    TargetCanvas.Font.Color := clRed; // visual cue for error
  end;
end;

procedure TVirtualJSONTree.TreeViewAfterCellPaint(Sender: TBaseVirtualTree; TargetCanvas: TCanvas;
  Node: PVirtualNode; Column: TColumnIndex; const CellRect: TRect);
var
  Data: PNodeDataRecord;
  NodeData: TJSONNodeData;
  X, Y: Integer;
  KeyPart, ValPart: string;
  IsSelected, IsExpanded: Boolean;
  TextMargin: Integer;
  IndentWidth: Integer;
  BtnCenterX, BtnCenterY, BtnSize: Integer;
  BtnRect: TRect;
begin
  if not Assigned(Node) then Exit;
  Data := Sender.GetNodeData(Node);
  if not Assigned(Data) then Exit;
  if Data^.IsGroup then Exit; // Let default drawing handle groups

  if (Data^.NodeIndex < 0) or (Data^.NodeIndex >= FIndex.Count) then Exit;

  NodeData := MaterializeNode(Data^.NodeIndex, Data^.ArrayIndex);
  IsExpanded := Sender.Expanded[Node];
  IsSelected := vsSelected in Node^.States;

  { Calculate text position to match where VT usually draws text }
  // We need to calculate the exact X coordinate where the text *should* start
  // to avoid overwriting the tree lines and +/- buttons.
  IndentWidth := 18;
  if Sender is TVirtualStringTree then
    IndentWidth := TVirtualStringTree(Sender).Indent;
  
  // Calculate base indent for this node's level, plus space for the +/- button
  TextMargin := (Sender.GetNodeLevel(Node) * IndentWidth) + IndentWidth + 2;
  
  // Also account for the tree margin itself
  TextMargin := TextMargin + 4; // Default margin
  
  X := CellRect.Left + TextMargin;
  
  { Align text vertically in the row }
  Y := CellRect.Top + ((CellRect.Bottom - CellRect.Top) - TargetCanvas.TextHeight('Xy')) div 2;

  // Overwrite ONLY the text area with the background color to erase the default text
  if IsSelected then
    TargetCanvas.Brush.Color := $00E1D5CD // VirtualTree-like light gray/blue selection
  else if (Node^.Index mod 2) = 1 then
    TargetCanvas.Brush.Color := $00F9F9F9  // Very light gray
  else
    TargetCanvas.Brush.Color := clWhite;
    
  TargetCanvas.Brush.Style := bsSolid;
  
  { IMPORTANT: Only clear from X (which includes the indent) to the right. 
    If we clear from CellRect.Left, we erase the +/- buttons and tree lines! }
  TargetCanvas.FillRect(Rect(X - 2, CellRect.Top, CellRect.Right, CellRect.Bottom));

  { Draw custom larger +/- buttons if the node has children }
  if vsHasChildren in Node^.States then
  begin
    // Calculate button center.
    // VirtualStringTree normally places the button at NodeLevel * Indent + Indent/2
    // We add 2 to X to account for minor internal VT offsets if needed, but let's stick to standard math.
    BtnSize := 14; // Larger button size (default is 9)
    BtnCenterX := CellRect.Left + (Sender.GetNodeLevel(Node) * IndentWidth) + (IndentWidth div 2);
    BtnCenterY := CellRect.Top + ((CellRect.Bottom - CellRect.Top) div 2);
    
    // Create the rectangle for our custom button
    BtnRect := Rect(BtnCenterX - (BtnSize div 2), BtnCenterY - (BtnSize div 2),
                    BtnCenterX + (BtnSize div 2) + 1, BtnCenterY + (BtnSize div 2) + 1);
                    
    // Erase the native button by filling our button rect with the background color
    if IsSelected then
      TargetCanvas.Brush.Color := $00E1D5CD
    else if (Node^.Index mod 2) = 1 then
      TargetCanvas.Brush.Color := $00F9F9F9
    else
      TargetCanvas.Brush.Color := clWhite;
    TargetCanvas.FillRect(BtnRect);
    
    // Draw the button border
    TargetCanvas.Brush.Style := bsClear;
    TargetCanvas.Pen.Color := $007A7A7A; // Dark gray border
    TargetCanvas.Pen.Width := 1;
    TargetCanvas.Rectangle(BtnRect);
    
    // Draw the + or - sign
    TargetCanvas.Pen.Color := clBlack;
    // Horizontal line
    TargetCanvas.MoveTo(BtnRect.Left + 3, BtnCenterY);
    TargetCanvas.LineTo(BtnRect.Right - 3, BtnCenterY);
    // Vertical line (if collapsed)
    if not IsExpanded then
    begin
      TargetCanvas.MoveTo(BtnCenterX, BtnRect.Top + 3);
      TargetCanvas.LineTo(BtnCenterX, BtnRect.Bottom - 3);
    end;
  end;

  TargetCanvas.Brush.Style := bsClear; // Transparent text background
  TargetCanvas.Font.Style := [];

  { 1. Draw Key / Array Index }
  if NodeData.Key <> '' then
  begin
    { VirtualTree style: Key is usually a muted green/blue like string }
    TargetCanvas.Font.Color := $00A57744; // VirtualTree green/blue for keys (BGR)
    TargetCanvas.TextOut(X, Y, NodeData.Key);
    X := X + TargetCanvas.TextWidth(NodeData.Key);

    TargetCanvas.Font.Color := $002A2A2A; // Dark gray/black for colon
    TargetCanvas.TextOut(X, Y, ' : ');
    X := X + TargetCanvas.TextWidth(' : ');
  end
  else if NodeData.ArrayIndex >= 0 then
  begin
    { [n] : value }
    TargetCanvas.Font.Color := $00A57744; // Same color for array index
    KeyPart := Format('[%d]', [NodeData.ArrayIndex]);
    TargetCanvas.TextOut(X, Y, KeyPart);
    X := X + TargetCanvas.TextWidth(KeyPart);

    TargetCanvas.Font.Color := $002A2A2A;
    TargetCanvas.TextOut(X, Y, ' : ');
    X := X + TargetCanvas.TextWidth(' : ');
  end;

  { 2. Draw Value }
  if IsExpanded and (NodeData.NodeType in [jntObject, jntArray]) then
  begin
    { If container is expanded, VirtualTree does not draw {...} or [...] next to the key }
  end
  else
  begin
    TargetCanvas.Font.Color := GetTypeColor(NodeData.NodeType);
    case NodeData.NodeType of
      jntObject: ValPart := '{...}';
      jntArray:  ValPart := '[...]';
      jntString: ValPart := '"' + NodeData.Value + '"';
    else
      ValPart := NodeData.Value;
    end;
    TargetCanvas.TextOut(X, Y, ValPart);
  end;
end;

procedure TVirtualJSONTree.TreeViewChange(Sender: TBaseVirtualTree; Node: PVirtualNode);
var
  Data: PNodeDataRecord;
begin
  try
    if Assigned(Node) then
    begin
      Data := Sender.GetNodeData(Node);
      if Assigned(Data) and not Data^.IsGroup and (Data^.NodeIndex >= 0) and (Data^.NodeIndex < FIndex.Count) then
        FSelectedNodeIndex := Data^.NodeIndex
      else
        FSelectedNodeIndex := -1;
    end
    else
      FSelectedNodeIndex := -1;

    if Assigned(FOnNodeSelected) then
      FOnNodeSelected(Self);
  except
    FSelectedNodeIndex := -1;
  end;
end;

{ ── Public Operations ────────────────────────────────────────────── }

procedure TVirtualJSONTree.Clear;
begin
  FTreeView.Clear;
  FSelectedNodeIndex := -1;
  FRootGrouped := False;
  FParsingInProgress := False;
end;

procedure TVirtualJSONTree.SetParsingInProgress(AValue: Boolean);
begin
  if FParsingInProgress = AValue then
    Exit;

  FParsingInProgress := AValue;
  FTreeView.Invalidate;
end;

procedure TVirtualJSONTree.CollapseAll;
begin
  FTreeView.FullCollapse;
end;

procedure TVirtualJSONTree.CollapseCurrentLevel;
var
  Node: PVirtualNode;
begin
  Node := FTreeView.FocusedNode;
  if Node <> nil then
  begin
    if FTreeView.Expanded[Node] then
      FTreeView.Expanded[Node] := False
    else if Node^.Parent <> FTreeView.RootNode then
      FTreeView.Expanded[Node^.Parent] := False;
  end;
end;

procedure TVirtualJSONTree.ExpandCurrentLevel;
var
  Node, ChildNode: PVirtualNode;
begin
  Node := FTreeView.FocusedNode;
  if Node <> nil then
  begin
    if not FTreeView.Expanded[Node] then
      FTreeView.Expanded[Node] := True
    else
    begin
      { If already expanded, expand its immediate children }
      ChildNode := FTreeView.GetFirstChild(Node);
      while ChildNode <> nil do
      begin
        FTreeView.Expanded[ChildNode] := True;
        ChildNode := FTreeView.GetNextSibling(ChildNode);
      end;
    end;
  end;
end;

procedure TVirtualJSONTree.NavigateToNode(ANodeIndex: Integer);
var
  Path: array of Integer;
  PathLen, Idx, I: Integer;
  Node: PVirtualNode;
  
  function FindChildNode(ParentNode: PVirtualNode; TargetJsonIdx: Integer; ParentJsonIdx: Integer): PVirtualNode;
  var
    ChildOrd, GroupIdx: Integer;
    CIdx: Integer;
    Entry: TJSONIndexEntry;
    C: PVirtualNode;
  begin
    Result := nil;
    ChildOrd := 0;
    CIdx := FIndex.GetFirstChild(ParentJsonIdx);
    while (CIdx >= 0) and (CIdx <> TargetJsonIdx) do
    begin
      Inc(ChildOrd);
      CIdx := FIndex.GetNextSibling(CIdx);
    end;
    
    Entry := FIndex[ParentJsonIdx];
    if Entry.ChildCount > MAX_NODES_PER_LEVEL then
    begin
      GroupIdx := ChildOrd div MAX_NODES_PER_LEVEL;
      ChildOrd := ChildOrd mod MAX_NODES_PER_LEVEL;
      
      if ParentNode = nil then C := FTreeView.GetFirst else C := FTreeView.GetFirstChild(ParentNode);
      while (C <> nil) and (GroupIdx > 0) do
      begin
        C := C^.NextSibling;
        Dec(GroupIdx);
      end;
      
      if C <> nil then
      begin
        FTreeView.Expanded[C] := True;
        ParentNode := C;
      end else Exit;
    end;
    
    if ParentNode = nil then C := FTreeView.GetFirst else C := FTreeView.GetFirstChild(ParentNode);
    while (C <> nil) and (ChildOrd > 0) do
    begin
      C := C^.NextSibling;
      Dec(ChildOrd);
    end;
    Result := C;
  end;

begin
  try
    if (ANodeIndex < 0) or (ANodeIndex >= FIndex.Count) then Exit;

    PathLen := 0;
    Idx := ANodeIndex;
    while (Idx >= 0) and (Idx < FIndex.Count) do
    begin
      Inc(PathLen);
      SetLength(Path, PathLen);
      Path[PathLen - 1] := Idx;
      Idx := FIndex[Idx].ParentIndex;
    end;

    if PathLen <= 1 then Exit; 

    Node := nil;
    for I := PathLen - 2 downto 0 do
    begin
      Node := FindChildNode(Node, Path[I], Path[I + 1]);
      if Node = nil then Break;
      if I > 0 then
        FTreeView.Expanded[Node] := True;
    end;

    if Node <> nil then
    begin
      FTreeView.ClearSelection;
      FTreeView.Selected[Node] := True;
      FTreeView.FocusedNode := Node;
      FTreeView.ScrollIntoView(Node, True);
    end;
  except
    // Fail silently instead of crashing the UI
  end;
end;

function TVirtualJSONTree.GetSelectedNodeData: TJSONNodeData;
var
  Node: PVirtualNode;
  Data: PNodeDataRecord;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.NodeIndex := -1;

  try
    Node := FTreeView.FocusedNode;
    if (Node = nil) or not FTreeView.Selected[Node] then
      Exit;

    Data := FTreeView.GetNodeData(Node);
    if not Assigned(Data) then Exit;
    if (Data^.NodeIndex < 0) or (Data^.NodeIndex >= FIndex.Count) then Exit;

    Result := MaterializeNode(Data^.NodeIndex, Data^.ArrayIndex);
  except
    // Fail safely and return the empty default struct
  end;
end;

function TVirtualJSONTree.GetSelectedNodePath: string;
var
  NodeData: TJSONNodeData;
  Path: array of string;
  PathLen: Integer;
  Idx: Integer;
  I: Integer;
begin
  if FSelectedNodeIndex < 0 then
    Exit('$');

  PathLen := 0;
  Idx := FSelectedNodeIndex;

  while Idx >= 0 do
  begin
    NodeData := MaterializeNode(Idx);

    Inc(PathLen);
    SetLength(Path, PathLen);

    if NodeData.ArrayIndex >= 0 then
      Path[PathLen - 1] := Format('[%d]', [NodeData.ArrayIndex])
    else if NodeData.Key <> '' then
      Path[PathLen - 1] := NodeData.Key
    else
      Path[PathLen - 1] := '';

    Idx := FIndex[Idx].ParentIndex;
  end;

  { Build path string (parts are in reverse order) }
  Result := '$';
  for I := PathLen - 2 downto 0 do  // Skip root
  begin
    if Path[I] = '' then
      Continue;
    if Path[I][1] = '[' then
      Result := Result + Path[I]
    else
      Result := Result + '.' + Path[I];
  end;
end;

{ ── Copy Operations ──────────────────────────────────────────────── }

procedure TVirtualJSONTree.CopySelectedName;
var
  Data: TJSONNodeData;
begin
  if FSelectedNodeIndex < 0 then Exit;
  Data := MaterializeNode(FSelectedNodeIndex);
  if Data.Key <> '' then
    Clipboard.AsText := Data.Key
  else if Data.ArrayIndex >= 0 then
    Clipboard.AsText := IntToStr(Data.ArrayIndex);
end;

procedure TVirtualJSONTree.CopySelectedValue;
var
  Data: TJSONNodeData;
begin
  if FSelectedNodeIndex < 0 then Exit;
  Data := MaterializeNode(FSelectedNodeIndex);
  Clipboard.AsText := GetNodeFullValue(Data);
end;

procedure TVirtualJSONTree.CopySelectedPath;
begin
  if FSelectedNodeIndex < 0 then Exit;
  Clipboard.AsText := GetSelectedNodePath;
end;

procedure TVirtualJSONTree.CopySelectedSubtreeAsJSON(ABeautified: Boolean);
var
  Entry: TJSONIndexEntry;
  RawJSON: string;
begin
  if FSelectedNodeIndex < 0 then Exit;
  Entry := FIndex[FSelectedNodeIndex];

  { Read the raw JSON for this subtree }
  RawJSON := ReadStringFromFile(Entry.FileOffset, Entry.FileLength);

  if ABeautified then
    Clipboard.AsText := BeautifyJSONString(RawJSON)
  else
    Clipboard.AsText := RawJSON;
end;

procedure TVirtualJSONTree.RefreshNode(ANodeIndex: Integer);
begin
  { Invalidate cache and re-materialize }
  FCache.Remove(ANodeIndex);
  { Force tree redraw }
  FTreeView.Invalidate;
end;

end.
