unit uFrmMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, IniFiles, Forms, Controls, Graphics, Dialogs, Menus,
  ExtCtrls, ComCtrls, Buttons, StdCtrls, ActnList, StdActns, Clipbrd,
  LCLType, VirtualTrees, laz.VirtualTrees,
  {$IFDEF WINDOWS}
  Registry,
  {$ENDIF}
  { Core }
  uJsonTypes, uJsonIndex, uFileHandler, uJsonParser, uStringPool, uDownloader,
  { Search }
  uSearchEngine, uJsonPath,
  { UI }
  uVirtualJsonTree, uStatusManager, ufrmopenurl,
  { Utils }
  uCache, uDataExporter;

type
  TAutoRefreshMode = (
    armNever,
    armAsk,
    armOnFocus,
    armAlways
  );

  { TFrmMain }

  TFrmMain = class(TForm)
    actlist: TActionList;
    btnPrevious: TBitBtn;
    btnNext: TBitBtn;
    edtSearch: TEdit;
    actFileExit: TFileExit;
    actFileOpen: TFileOpen;
    actFileSaveAs: TFileSaveAs;
    Label1: TLabel;
    mnuExportAsJSON: TMenuItem;
    mnuExportSectionAsMinifiedJSON: TMenuItem;
    mnuExportSectionAsBeautifiedJSON: TMenuItem;
    mnuExportSectionAsMinifiedXML: TMenuItem;
    mnuExportSectionAsBeautifiedXML: TMenuItem;
    mnuExportSectionAsCSV: TMenuItem;
    mnuExportSectionAsYAML: TMenuItem;
    mnuExportSectionAsTOML: TMenuItem;
    mnuExportAsMinifiedJSON: TMenuItem;
    mnuExportAsBeautifiedJSON: TMenuItem;
    mnuExportAsMinifiedXML: TMenuItem;
    mnuExportAsBeautifiedXML: TMenuItem;
    mnuExportAsCSV: TMenuItem;
    mnuExportAsYAML: TMenuItem;
    mnuExportAsTOML: TMenuItem;
    mnuExportSectionAsJSON: TMenuItem;
    mnuExpandCurrentLevel: TMenuItem;
    mnuBeautifiedValue: TMenuItem;
    mnuMinifiedValue: TMenuItem;
    mnuBeautifiedJson: TMenuItem;
    mnuMinifiedJson: TMenuItem;
    mnuMain: TMainMenu;
    mnuFile: TMenuItem;
    mnuHelp: TMenuItem;
    mnuExportAs: TMenuItem;
    mnuExportSectionAs: TMenuItem;
    mnuQuit: TMenuItem;
    mnuFind: TMenuItem;
    mnuFindNext: TMenuItem;
    mnuFindPrevious: TMenuItem;
    mnuCopyData: TMenuItem;
    mnuCopyDataAs: TMenuItem;
    mnuCopySelectionName: TMenuItem;
    mnuCopySelectionValue: TMenuItem;
    mnuCopySelectionValueAs: TMenuItem;
    mnuCopySelectionPath: TMenuItem;
    mnuHideStatusBar: TMenuItem;
    mnuPreferences: TMenuItem;
    mnuHideNodePath: TMenuItem;
    mnuRefresh: TMenuItem;
    mnuCollapseAllNode: TMenuItem;
    mnuCollapseCurrentLevel: TMenuItem;
    mnuReleaseNotes: TMenuItem;
    mnuAbout: TMenuItem;

    { Context Menu Components }
    popTree: TPopupMenu;
    popCopyName: TMenuItem;
    popCopyValue: TMenuItem;
    popCopyValueAs: TMenuItem;
    popCopyMinifiedValue: TMenuItem;
    popCopyFormattedValue: TMenuItem;
    popCopyPath: TMenuItem;
    popSeparator1: TMenuItem;
    popExportValueAs: TMenuItem;
    popExportJSON: TMenuItem;
    popExportMinifiedJSON: TMenuItem;
    popExportFormattedJSON: TMenuItem;
    popSeparator2: TMenuItem;
    popExportMinifiedXML: TMenuItem;
    popExportFormattedXML: TMenuItem;
    popSeparator3: TMenuItem;
    popExportCSV: TMenuItem;
    popExportYAML: TMenuItem;
    popExportTOML: TMenuItem;

    Panel1: TPanel;
    pnlTreeViewContainer: TPanel;
    pnlContainer: TPanel;
    pnlTop: TPanel;
    pnlStatusBarContainer: TPanel;
    Separator10: TMenuItem;
    Separator11: TMenuItem;
    Separator12: TMenuItem;
    Separator13: TMenuItem;
    Separator14: TMenuItem;
    Separator15: TMenuItem;
    Separator4: TMenuItem;
    Separator3: TMenuItem;
    Separator2: TMenuItem;
    Separator1: TMenuItem;
    mnuNewWindow: TMenuItem;
    mnuOpen: TMenuItem;
    mnuOpenFolder: TMenuItem;
    mnuRecentFiles: TMenuItem;
    mnuOpenURL: TMenuItem;
    mnuPasteClipboard: TMenuItem;
    mnuEdit: TMenuItem;
    mnuView: TMenuItem;
    Separator5: TMenuItem;
    Separator6: TMenuItem;
    Separator7: TMenuItem;
    Separator8: TMenuItem;
    Separator9: TMenuItem;
    btnCase: TSpeedButton;
    btnRegEx: TSpeedButton;
    StatusBar1: TStatusBar;
    StatusBar2: TStatusBar;

    procedure Action1Execute(Sender: TObject);
    procedure btnCaseClick(Sender: TObject);
    procedure btnPreviousClick(Sender: TObject);
    procedure edtSearchChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormActivate(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure mnuExpandCurrentLevelClick(Sender: TObject);
    procedure mnuAboutClick(Sender: TObject);
    procedure mnuBeautifiedJsonClick(Sender: TObject);
    procedure mnuBeautifiedValueClick(Sender: TObject);
    procedure mnuCollapseAllNodeClick(Sender: TObject);
    procedure mnuCollapseCurrentLevelClick(Sender: TObject);
    procedure mnuCopyDataClick(Sender: TObject);
    procedure mnuCopySelectionNameClick(Sender: TObject);
    procedure mnuCopySelectionPathClick(Sender: TObject);
    procedure mnuCopySelectionValueClick(Sender: TObject);
    procedure mnuExportAsClick(Sender: TObject);
    procedure mnuExportSectionAsClick(Sender: TObject);
    procedure mnuExportSectionAsJSONClick(Sender: TObject);
    procedure mnuFileClick(Sender: TObject);
    procedure mnuEditClick(Sender: TObject);
    procedure mnuFindClick(Sender: TObject);
    procedure mnuFindNextClick(Sender: TObject);
    procedure mnuFindPreviousClick(Sender: TObject);
    procedure mnuHideNodePathClick(Sender: TObject);
    procedure mnuHideStatusBarClick(Sender: TObject);
    procedure mnuMinifiedJsonClick(Sender: TObject);
    procedure mnuMinifiedValueClick(Sender: TObject);
    procedure mnuNewWindowClick(Sender: TObject);
    procedure mnuOpenClick(Sender: TObject);
    procedure mnuOpenFolderClick(Sender: TObject);
    procedure mnuOpenURLClick(Sender: TObject);
    procedure mnuPasteClipboardClick(Sender: TObject);
    procedure mnuPreferencesClick(Sender: TObject);
    procedure mnuQuitClick(Sender: TObject);
    procedure mnuRecentFilesClick(Sender: TObject);
    procedure mnuRefreshClick(Sender: TObject);
    procedure mnuReleaseNotesClick(Sender: TObject);
    procedure btnNextClick(Sender: TObject);
    procedure btnRegExClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure popCopyNameClick(Sender: TObject);
    procedure popCopyValueClick(Sender: TObject);
    procedure popCopyMinifiedValueClick(Sender: TObject);
    procedure popCopyFormattedValueClick(Sender: TObject);
    procedure popCopyPathClick(Sender: TObject);
    procedure popExportJSONClick(Sender: TObject);
    procedure popExportMinifiedJSONClick(Sender: TObject);
    procedure popExportFormattedJSONClick(Sender: TObject);
    procedure popExportMinifiedXMLClick(Sender: TObject);
    procedure popExportFormattedXMLClick(Sender: TObject);
    procedure popExportCSVClick(Sender: TObject);
    procedure popExportYAMLClick(Sender: TObject);
    procedure popExportTOMLClick(Sender: TObject);
  private
    { ── Core subsystems ────────────────────────────────────── }
    FFileHandler: TFileHandler;
    FIndex: TJSONIndex;
    FStringPool: TStringPool;
    FNodeCache: TNodeCache;

    { ── Search ─────────────────────────────────────────────── }
    FSearchEngine: TSearchEngine;
    FPathBuilder: TJSONPathBuilder;

    { ── UI Controllers ─────────────────────────────────────── }
    FVirtualTree: TVirtualJSONTree;
    FStatusManager: TStatusManager;

    { ── Dynamically created UI components ──────────────────── }
    FTreeView: TVirtualStringTree;
    FDetailMemo: TMemo;
    FSplitter: TSplitter;
    FDetailHeaderLabel: TLabel;
    FWelcomeLabel: TLabel;
    FAlwaysOnTopMenuItem: TMenuItem;

    { ── State ──────────────────────────────────────────────── } 
    FCurrentFileName: string;
    FSearchDebounceTimer: TTimer;
    FFileWatchTimer: TTimer;
    FCaseSensitive: Boolean;
    FUseRegEx: Boolean;
    FSearchThread: TThread;
    FInitialFocusHandled: Boolean;
    FAutoRefreshMode: TAutoRefreshMode;
    FAlwaysOnTop: Boolean;
    FSessionAlwaysOnTop: Boolean;
    FStartupFileName: string;
    FStartupFilePending: Boolean;
    FCurrentFileSignature: string;
    FPendingFileChange: Boolean;

    { ── Recent Files ───────────────────────────────────────── } 
    FRecentFiles: TStringList;
    procedure LoadRecentFiles;
    procedure SaveRecentFiles;
    procedure UpdateRecentFilesMenu;
    procedure AddRecentFile(const AFileName: string);
    procedure OnRecentFileClick(Sender: TObject);

    { ── Private methods ────────────────────────────────────── }
    procedure CreateUIComponents;
    procedure InitializeSubsystems;
    procedure DestroySubsystems;
    function IsTextInputControl(AControl: TWinControl): Boolean;
    function TryExtractParseByteOffset(const ErrorMsg: string; out AOffset: Int64): Boolean;
    function StripParseByteOffset(const ErrorMsg: string): string;
    function DetectCurrentFileEncoding: TJSONEncoding;
    function TryBuildParseErrorContext(const ErrorMsg: string; out AContext: string): Boolean;
    function IsClipboardTempFile(const AFileName: string): Boolean;
    function GetEmptyJSONMessage(const AFileName: string): string;
    function GetPreferencesFileName: string;
    function TryGetFileChangeSignature(const AFileName: string; out ASignature: string): Boolean;
    function IsWatchableFile(const AFileName: string): Boolean;
    function IsJSONFileAssociated: Boolean;
    function TrySetJSONFileAssociation(out AErrorMessage: string): Boolean;
    function TryRemoveJSONFileAssociation(out AErrorMessage: string): Boolean;

    procedure LoadPreferences;
    procedure SavePreferences;
    procedure ApplyAlwaysOnTop;
    procedure UpdateAlwaysOnTopMenuState;
    procedure UpdateCurrentFileSignature;
    function ConfirmLargeFileRefresh: Boolean;
    procedure ReloadCurrentFile;
    procedure HandleDetectedFileChange(AFromActivation: Boolean);
    procedure OnFileWatchTimer(Sender: TObject);
    procedure LoadFile(const AFileName: string);
    procedure CloseCurrentFile;
    procedure UpdateDetailPanel;
    procedure UpdateTitle;

    { Event handlers for subsystem callbacks }
    procedure OnTreeNodeSelected(Sender: TObject);
    procedure OnParseCompleted(const AFileName: string; ElapsedMs: Int64; const AWarning: string = '');
    procedure OnParseError(const AFileName: string; const ErrorMsg: string);
    procedure OnSearchDebounce(Sender: TObject);
    
    { Download callbacks }
    procedure OnDownloadProgress(const Msg: string; Percent: Integer);
    procedure OnDownloadComplete(const TempFile: string);
    procedure OnDownloadError(const ErrorMsg: string);

    procedure ExecuteSearch;
    procedure NavigateToSearchResult(ANodeIndex: Integer);
    procedure ToggleAlwaysOnTopClick(Sender: TObject);

    { Export helpers }
    procedure ExportToFile(const AData: string; AFormat: TExportFormat);

    { Drag-drop handler }
    procedure HandleDropFiles(Sender: TObject; const FileNames: array of string);
  public
    procedure QueueStartupFile(const AFileName: string);
  end;

var
  FrmMain: TFrmMain;

implementation

{$R *.lfm}

function GetAppConfigFolder: string; forward;
function GetJSONAssociationIconPath: string; forward;

const
  {$IFDEF CPUX86_64}
  ARCH_SUFFIX = 'x64 (AVX2)';
  {$ELSE}
  {$IFDEF CPUAARCH64}
  ARCH_SUFFIX = 'ARM64 (NEON)';
  {$ELSE}
  {$IFDEF CPUARM}
  ARCH_SUFFIX = 'ARM (NEON)';
  {$ELSE}
  ARCH_SUFFIX = 'x86 (Scalar)';
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  
  APP_TITLE = 'Large JSON Viewer ' + ARCH_SUFFIX;
  APP_VERSION = '1.0.0';
  SEARCH_DEBOUNCE_MS = 300;
  FILE_WATCH_INTERVAL_MS = 1500;
  LARGE_FILE_REFRESH_CONFIRM_BYTES = 50 * 1024 * 1024;
  PREFERENCES_CFG = 'lazjson_preferences.ini';
  PREF_SECTION_GENERAL = 'General';
  PREF_KEY_AUTO_REFRESH = 'AutoRefreshMode';
  PREF_KEY_ALWAYS_ON_TOP = 'AlwaysOnTop';
  JSON_FILE_PROGID = 'LargeJSONViewer';
  JSON_FILE_ICON_RESOURCE_ID = 200;

type
  TPreferencesDialog = class(TForm)
  private
    FMainForm: TFrmMain;
    FAutoRefreshLabel: TLabel;
    FAutoRefreshCombo: TComboBox;
    FAssociationTitleLabel: TLabel;
    FAssociationStatusLabel: TLabel;
    FAssociationButton: TButton;
    FAlwaysOnTopCheckBox: TCheckBox;
    FOKButton: TButton;
    FCancelButton: TButton;
    procedure AssociateButtonClick(Sender: TObject);
  public
    constructor CreateDialog(AOwner: TComponent; AMainForm: TFrmMain);
    function GetAutoRefreshMode: TAutoRefreshMode;
    function GetAlwaysOnTop: Boolean;
    procedure SetAutoRefreshMode(AMode: TAutoRefreshMode);
    procedure SetAlwaysOnTop(AValue: Boolean);
    procedure UpdateAssociationStatus;
  end;

  { Background thread to parse JSON without blocking UI }
  TParseThread = class(TThread)
  private
    FMainForm: TFrmMain;
    FFileName: string;
    FIndex: TJSONIndex;
    FStringPool: TStringPool;
    FExceptionMsg: string;
    FElapsedMs: Int64;

    { Sync fields for UI cross-talk }
    FSyncMsg: string;
    FSyncPct: Integer;
    FQueuePending: Boolean;

    procedure SyncProgress;
    procedure SyncDone;
    procedure SyncError;
    procedure OnParseProgress(const Info: TParseProgressInfo);
  protected
    procedure Execute; override;
  public
    constructor Create(AMainForm: TFrmMain; const AFileName: string;
      AIndex: TJSONIndex; AStrPool: TStringPool);
  end;

  { Background thread to perform searches without blocking UI }
  TSearchThread = class(TThread)
  private
    FMainForm: TFrmMain;
    FSearchEngine: TSearchEngine;
    FQuery: string;
    FCaseSensitive: Boolean;
    FUseRegEx: Boolean;
    procedure SyncDone;
  protected
    procedure Execute; override;
  public
    constructor Create(AMainForm: TFrmMain; AEngine: TSearchEngine; const AQuery: string;
      ACaseSens, ARegEx: Boolean);
  end;

{ ── TPreferencesDialog ────────────────────────────────────────────────── }

constructor TPreferencesDialog.CreateDialog(AOwner: TComponent; AMainForm: TFrmMain);
begin
  inherited CreateNew(AOwner, 1);
  FMainForm := AMainForm;

  Caption := 'Preferences';
  BorderIcons := [biSystemMenu];
  BorderStyle := bsDialog;
  Position := poScreenCenter;
  ClientWidth := 520;
  ClientHeight := 220;

  FAutoRefreshLabel := TLabel.Create(Self);
  FAutoRefreshLabel.Parent := Self;
  FAutoRefreshLabel.Caption := 'Auto-refresh file on changes';
  FAutoRefreshLabel.Left := 24;
  FAutoRefreshLabel.Top := 28;

  FAutoRefreshCombo := TComboBox.Create(Self);
  FAutoRefreshCombo.Parent := Self;
  FAutoRefreshCombo.Style := csDropDownList;
  FAutoRefreshCombo.Left := 280;
  FAutoRefreshCombo.Top := 24;
  FAutoRefreshCombo.Width := 200;
  FAutoRefreshCombo.Items.Add('Never');
  FAutoRefreshCombo.Items.Add('Needs confirmation');
  FAutoRefreshCombo.Items.Add('On focus');
  FAutoRefreshCombo.Items.Add('Always');

  FAlwaysOnTopCheckBox := TCheckBox.Create(Self);
  FAlwaysOnTopCheckBox.Parent := Self;
  FAlwaysOnTopCheckBox.Caption := 'Always on top';
  FAlwaysOnTopCheckBox.Left := 24;
  FAlwaysOnTopCheckBox.Top := 60;

  FAssociationTitleLabel := TLabel.Create(Self);
  FAssociationTitleLabel.Parent := Self;
  FAssociationTitleLabel.Caption := 'JSON file association';
  FAssociationTitleLabel.Left := 24;
  FAssociationTitleLabel.Top := 104;

  FAssociationStatusLabel := TLabel.Create(Self);
  FAssociationStatusLabel.Parent := Self;
  FAssociationStatusLabel.Left := 24;
  FAssociationStatusLabel.Top := 128;
  FAssociationStatusLabel.Width := 320;
  FAssociationStatusLabel.AutoSize := False;

  FAssociationButton := TButton.Create(Self);
  FAssociationButton.Parent := Self;
  FAssociationButton.Caption := 'Associate .json Files';
  FAssociationButton.Left := 352;
  FAssociationButton.Top := 120;
  FAssociationButton.Width := 128;
  FAssociationButton.OnClick := @AssociateButtonClick;

  FOKButton := TButton.Create(Self);
  FOKButton.Parent := Self;
  FOKButton.Caption := 'OK';
  FOKButton.Left := 320;
  FOKButton.Top := 176;
  FOKButton.Width := 75;
  FOKButton.ModalResult := mrOk;
  FOKButton.Default := True;

  FCancelButton := TButton.Create(Self);
  FCancelButton.Parent := Self;
  FCancelButton.Caption := 'Cancel';
  FCancelButton.Left := 405;
  FCancelButton.Top := 176;
  FCancelButton.Width := 75;
  FCancelButton.ModalResult := mrCancel;
  FCancelButton.Cancel := True;

  UpdateAssociationStatus;
end;

procedure TPreferencesDialog.AssociateButtonClick(Sender: TObject);
var
  ErrorMessage: string;
begin
  if FMainForm = nil then
    Exit;

  if FMainForm.IsJSONFileAssociated then
  begin
    if FMainForm.TryRemoveJSONFileAssociation(ErrorMessage) then
      MessageDlg('JSON Association',
        'JSON file association was removed for the current user.',
        mtInformation, [mbOK], 0)
    else
      MessageDlg('JSON Association',
        ErrorMessage,
        mtWarning, [mbOK], 0);
  end
  else
  begin
    if FMainForm.TrySetJSONFileAssociation(ErrorMessage) then
      MessageDlg('JSON Association',
        'JSON files are now associated with Large JSON Viewer for the current user.',
        mtInformation, [mbOK], 0)
    else
      MessageDlg('JSON Association',
        ErrorMessage,
        mtWarning, [mbOK], 0);
  end;

  UpdateAssociationStatus;
end;

function TPreferencesDialog.GetAutoRefreshMode: TAutoRefreshMode;
begin
  case FAutoRefreshCombo.ItemIndex of
    0: Result := armNever;
    2: Result := armOnFocus;
    3: Result := armAlways;
  else
    Result := armAsk;
  end;
end;

function TPreferencesDialog.GetAlwaysOnTop: Boolean;
begin
  Result := FAlwaysOnTopCheckBox.Checked;
end;

procedure TPreferencesDialog.SetAutoRefreshMode(AMode: TAutoRefreshMode);
begin
  case AMode of
    armNever:
      FAutoRefreshCombo.ItemIndex := 0;
    armOnFocus:
      FAutoRefreshCombo.ItemIndex := 2;
    armAlways:
      FAutoRefreshCombo.ItemIndex := 3;
  else
    FAutoRefreshCombo.ItemIndex := 1;
  end;
end;

procedure TPreferencesDialog.SetAlwaysOnTop(AValue: Boolean);
begin
  FAlwaysOnTopCheckBox.Checked := AValue;
end;

procedure TPreferencesDialog.UpdateAssociationStatus;
begin
  if (FMainForm <> nil) and FMainForm.IsJSONFileAssociated then
  begin
    FAssociationStatusLabel.Caption := 'Status: Associated with Large JSON Viewer';
    FAssociationButton.Caption := 'Disassociate .json Files';
  end
  else
  begin
    FAssociationStatusLabel.Caption := 'Status: Not associated with Large JSON Viewer';
    FAssociationButton.Caption := 'Associate .json Files';
  end;
end;

{ ── TParseThread ──────────────────────────────────────────────────────── }

constructor TParseThread.Create(AMainForm: TFrmMain; const AFileName: string;
  AIndex: TJSONIndex; AStrPool: TStringPool);
begin
  inherited Create(True); // Create suspended so we can set FreeOnTerminate before Start
  FreeOnTerminate := True;
  FMainForm := AMainForm;
  FFileName := AFileName;
  FIndex := AIndex;
  FStringPool := AStrPool;
  FQueuePending := False;
end;

procedure TParseThread.Execute;
var
  Parser: TStreamingJSONParser;
  LocalFileHandler: TFileHandler;
  StartTime: QWord;
begin
  LocalFileHandler := TFileHandler.Create;
  try
    LocalFileHandler.OpenFile(FFileName);
    
    if LocalFileHandler.FileSize < TIER_SMALL_MAX then
      FIndex.Reserve(LocalFileHandler.FileSize div 20)
    else
      FIndex.Reserve(65536);

    Parser := TStreamingJSONParser.Create(LocalFileHandler, FIndex, FStringPool);
    try
      Parser.OnProgress := @OnParseProgress;
      StartTime := GetTickCount64;
      Parser.Parse;
      FElapsedMs := GetTickCount64 - StartTime;
      if Parser.ErrorMessage <> '' then
        FExceptionMsg := Parser.ErrorMessage;
    finally
      Parser.Free;
    end;

    if not Terminated then
      Synchronize(@SyncDone);
  except
    on E: Exception do
    begin
      FExceptionMsg := E.Message;
      if not Terminated then
        Synchronize(@SyncError);
    end;
  end;
  LocalFileHandler.Free;
end;

procedure TParseThread.OnParseProgress(const Info: TParseProgressInfo);
begin
  if Terminated then Exit; // The parser doesn't natively abort yet unless an exception is thrown
  
  FSyncPct := Trunc(Info.Percentage * 100);
  FSyncMsg := Format('Parsing... [%.1f MB / %.1f MB] - %d nodes',
    [Info.BytesProcessed / (1024*1024), Info.TotalBytes / (1024*1024), Info.NodesFound]);
    
  if not FQueuePending then
  begin
    FQueuePending := True;
    Queue(@SyncProgress);
  end;
end;

procedure TParseThread.SyncProgress;
begin
  FMainForm.FStatusManager.SetProgress(FSyncMsg, FSyncPct);
  
  { Instantly stream parsed root nodes to the UI while parsing }
  if FMainForm.FTreeView.RootNodeCount = 0 then
  begin
    FMainForm.FVirtualTree.BuildRootNodes;
    if FMainForm.FTreeView.RootNodeCount > 0 then
    begin
      FMainForm.FWelcomeLabel.Visible := False;
      FMainForm.FTreeView.Visible := True;
    end;
  end
  else
    FMainForm.FVirtualTree.UpdateRootCount;

  FQueuePending := False;
end;

procedure TParseThread.SyncDone;
begin
  FMainForm.OnParseCompleted(FFileName, FElapsedMs, FExceptionMsg);
end;

procedure TParseThread.SyncError;
begin
  FMainForm.OnParseError(FFileName, FExceptionMsg);
end;

{ ── TSearchThread ─────────────────────────────────────────────────────── }

constructor TSearchThread.Create(AMainForm: TFrmMain; AEngine: TSearchEngine;
  const AQuery: string; ACaseSens, ARegEx: Boolean);
begin
  inherited Create(True);
  FreeOnTerminate := True;
  FMainForm := AMainForm;
  FSearchEngine := AEngine;
  FQuery := AQuery;
  FCaseSensitive := ACaseSens;
  FUseRegEx := ARegEx;
end;

procedure TSearchThread.Execute;
begin
  { This may take a few seconds on huge files, but it won't block the UI }
  FSearchEngine.Search(FQuery, smAll, FCaseSensitive, FUseRegEx);

  if not Terminated and not FSearchEngine.IsSearching then
    Synchronize(@SyncDone);
end;

procedure TSearchThread.SyncDone;
var
  NodeIdx: Integer;
begin
  if not Assigned(FMainForm.FSearchThread) then Exit; // Ensure we haven't been canceled/closed
  
  FMainForm.FSearchThread := nil;
  Screen.Cursor := crDefault;
  
  FMainForm.FStatusManager.SetSearchInfo(FMainForm.FSearchEngine.GetResultInfo);

  { Navigate to first result }
  if FMainForm.FSearchEngine.ResultCount > 0 then
  begin
    NodeIdx := FMainForm.FSearchEngine.NextResult;
    if NodeIdx >= 0 then
      FMainForm.NavigateToSearchResult(NodeIdx);
  end;
end;

{ ══════════════════════════════════════════════════════════════════════
  FORM LIFECYCLE
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.FormCreate(Sender: TObject);
begin
  KeyPreview := True;
  OnActivate := @FormActivate;
  OnKeyDown := @FormKeyDown;
  OnShow := @FormShow;
  FCaseSensitive := False;
  FUseRegEx := False;
  FCurrentFileName := '';
  FInitialFocusHandled := False;
  FAutoRefreshMode := armAsk;
  FAlwaysOnTop := False;
  FSessionAlwaysOnTop := False;
  FStartupFileName := '';
  FStartupFilePending := False;
  FCurrentFileSignature := '';
  FPendingFileChange := False;

  { Create UI components programmatically }
  CreateUIComponents;

  { Initialize all subsystems }
  InitializeSubsystems;

  { Setup search debounce timer }
  FSearchDebounceTimer := TTimer.Create(Self);
  FSearchDebounceTimer.Interval := SEARCH_DEBOUNCE_MS;
  FSearchDebounceTimer.Enabled := False;
  FSearchDebounceTimer.OnTimer := @OnSearchDebounce;

  FFileWatchTimer := TTimer.Create(Self);
  FFileWatchTimer.Interval := FILE_WATCH_INTERVAL_MS;
  FFileWatchTimer.Enabled := True;
  FFileWatchTimer.OnTimer := @OnFileWatchTimer;

  LoadPreferences;
  FSessionAlwaysOnTop := FAlwaysOnTop;
  ApplyAlwaysOnTop;

  { Setup keyboard shortcut for Find }
  mnuFind.ShortCut := ShortCut(VK_F, [ssCtrl]);
  mnuFindNext.ShortCut := ShortCut(VK_F3, []);
  mnuFindPrevious.ShortCut := ShortCut(VK_F3, [ssShift]);

  { Configure file open action }
  actFileOpen.Dialog.Filter :=
    'JSON Files (*.json)|*.json|' +
    'All Files (*.*)|*.*';
  actFileOpen.Dialog.Title := 'Open JSON File';
  actFileOpen.OnAccept := @mnuOpenClick;

  { Initial UI state }
  UpdateTitle;

  { Accept file drops }
  AllowDropFiles := True;
  OnDropFiles := @HandleDropFiles;
  
  { Load Recent Files }
  LoadRecentFiles;
end;

procedure TFrmMain.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = VK_V) and (ssCtrl in Shift) and (not IsTextInputControl(ActiveControl)) then
  begin
    mnuPasteClipboardClick(mnuPasteClipboard);
    Key := 0;
  end;
end;

procedure TFrmMain.FormActivate(Sender: TObject);
begin
  HandleDetectedFileChange(True);
end;

procedure TFrmMain.FormShow(Sender: TObject);
begin
  if not FInitialFocusHandled then
  begin
    FInitialFocusHandled := True;
    if ActiveControl = edtSearch then
      ActiveControl := nil;
  end;

  if FStartupFilePending and (FStartupFileName <> '') then
  begin
    FStartupFilePending := False;
    LoadFile(FStartupFileName);
  end;
end;

procedure TFrmMain.mnuExpandCurrentLevelClick(Sender: TObject);
begin
  if FVirtualTree <> nil then
    FVirtualTree.ExpandCurrentLevel;
end;

procedure TFrmMain.FormDestroy(Sender: TObject);
begin
  SavePreferences;
  if FRecentFiles <> nil then
    FRecentFiles.Free;
  DestroySubsystems;
end;

function TFrmMain.IsTextInputControl(AControl: TWinControl): Boolean;
begin
  Result := (AControl is TCustomEdit) or
            (AControl is TCustomComboBox);
end;

function TFrmMain.TryExtractParseByteOffset(const ErrorMsg: string; out AOffset: Int64): Boolean;
const
  MarkerText = ' at byte offset ';
var
  MarkerPos: SizeInt;
  StartPos: SizeInt;
  EndPos: SizeInt;
  OffsetText: string;
begin
  Result := False;
  AOffset := -1;

  MarkerPos := Pos(MarkerText, ErrorMsg);
  if MarkerPos <= 0 then
    Exit;

  StartPos := MarkerPos + Length(MarkerText);
  EndPos := StartPos;
  while (EndPos <= Length(ErrorMsg)) and (ErrorMsg[EndPos] in ['0'..'9']) do
    Inc(EndPos);

  OffsetText := Copy(ErrorMsg, StartPos, EndPos - StartPos);
  if OffsetText = '' then
    Exit;

  Result := TryStrToInt64(OffsetText, AOffset);
end;

function TFrmMain.StripParseByteOffset(const ErrorMsg: string): string;
const
  MarkerText = ' at byte offset ';
var
  MarkerPos: SizeInt;
begin
  MarkerPos := Pos(MarkerText, ErrorMsg);
  if MarkerPos > 0 then
    Result := Copy(ErrorMsg, 1, MarkerPos - 1)
  else
    Result := ErrorMsg;
end;

function TFrmMain.DetectCurrentFileEncoding: TJSONEncoding;
var
  Header: TBytes;
begin
  Result := jeUTF8;
  if (FFileHandler = nil) or (not FFileHandler.IsOpen) then
    Exit;

  Header := FFileHandler.ReadBytes(0, 4);
  if Length(Header) >= 3 then
  begin
    if (Header[0] = $EF) and (Header[1] = $BB) and (Header[2] = $BF) then
      Exit(jeUTF8);
  end;

  if Length(Header) >= 2 then
  begin
    if (Header[0] = $FF) and (Header[1] = $FE) then
      Exit(jeUTF16LE);
    if (Header[0] = $FE) and (Header[1] = $FF) then
      Exit(jeUTF16BE);
  end;

  if Length(Header) >= 4 then
  begin
    if (Header[0] <> 0) and (Header[1] = 0) and (Header[2] <> 0) and (Header[3] = 0) then
      Exit(jeUTF16LE);
    if (Header[0] = 0) and (Header[1] <> 0) and (Header[2] = 0) and (Header[3] <> 0) then
      Exit(jeUTF16BE);
  end;
end;

function TFrmMain.TryBuildParseErrorContext(const ErrorMsg: string; out AContext: string): Boolean;
const
  ScanChunkSize = 65536;
  ContextCharsBefore = 30;
  ContextCharsAfter = 50;
  MarkerText = ' <<<HERE>>> ';
var
  ErrorOffset: Int64;
  ScanLimit: Int64;
  ScanOffset: Int64;
  BytesToRead: Integer;
  Buffer: TBytes;
  BufferIndex: Integer;
  LineNumber: Int64;
  LineStartOffset: Int64;
  PrevWasCR: Boolean;
  Encoding: TJSONEncoding;
  CharStride: Integer;
  ContextStartOffset: Int64;
  ContextEndOffset: Int64;
  ContextText: string;
  CurrentOffset: Int64;
  CharValue: Word;
  MarkerInserted: Boolean;
  ContextStartCut: Boolean;
  ContextEndCut: Boolean;
  ReadOffset: Int64;
  ReadLength: Int64;
  MaxContextBytes: Int64;

  procedure AppendVisibleChar(ACharValue: Word);
  begin
    if ACharValue in [9, 10, 13] then
      ContextText := ContextText + ' '
    else if (ACharValue >= 32) and (ACharValue <= 126) then
      ContextText := ContextText + Chr(ACharValue)
    else
      ContextText := ContextText + '?';
  end;

begin
  Result := False;
  AContext := '';

  if (FFileHandler = nil) or (not FFileHandler.IsOpen) then
    Exit;

  if not TryExtractParseByteOffset(ErrorMsg, ErrorOffset) then
    Exit;

  if ErrorOffset < 0 then
    Exit;

  if ErrorOffset > FFileHandler.FileSize then
    ErrorOffset := FFileHandler.FileSize;

  Encoding := DetectCurrentFileEncoding;
  if Encoding = jeUTF8 then
    CharStride := 1
  else
    CharStride := 2;

  ScanLimit := ErrorOffset;
  if (CharStride = 2) and Odd(ScanLimit) then
    Dec(ScanLimit);

  LineNumber := 1;
  LineStartOffset := 0;
  PrevWasCR := False;
  ScanOffset := 0;

  while ScanOffset < ScanLimit do
  begin
    BytesToRead := ScanChunkSize;
    if ScanOffset + BytesToRead > ScanLimit then
      BytesToRead := ScanLimit - ScanOffset;
    if (CharStride = 2) and Odd(BytesToRead) then
      Dec(BytesToRead);
    if BytesToRead <= 0 then
      Break;

    Buffer := FFileHandler.ReadBytes(ScanOffset, BytesToRead);
    BufferIndex := 0;
    while BufferIndex < Length(Buffer) do
    begin
      if Encoding = jeUTF8 then
      begin
        CharValue := Buffer[BufferIndex];
        Inc(BufferIndex);
      end
      else
      begin
        if BufferIndex + 1 >= Length(Buffer) then
          Break;
        if Encoding = jeUTF16LE then
          CharValue := Buffer[BufferIndex] or (Buffer[BufferIndex + 1] shl 8)
        else
          CharValue := (Buffer[BufferIndex] shl 8) or Buffer[BufferIndex + 1];
        Inc(BufferIndex, 2);
      end;

      if CharValue = 13 then
      begin
        Inc(LineNumber);
        LineStartOffset := ScanOffset + BufferIndex;
        PrevWasCR := True;
      end
      else if CharValue = 10 then
      begin
        if not PrevWasCR then
          Inc(LineNumber);
        LineStartOffset := ScanOffset + BufferIndex;
        PrevWasCR := False;
      end
      else
        PrevWasCR := False;
    end;

    Inc(ScanOffset, BytesToRead);
  end;

  ContextStartOffset := ErrorOffset - (ContextCharsBefore * CharStride);
  if ContextStartOffset < LineStartOffset then
    ContextStartOffset := LineStartOffset;
  if ContextStartOffset < 0 then
    ContextStartOffset := 0;

  MaxContextBytes := (ContextCharsBefore + ContextCharsAfter + 20) * CharStride;
  ContextEndOffset := ContextStartOffset + MaxContextBytes;
  if ContextEndOffset > FFileHandler.FileSize then
    ContextEndOffset := FFileHandler.FileSize;
  if (CharStride = 2) and Odd(ContextEndOffset) then
    Dec(ContextEndOffset);

  if ContextEndOffset < ContextStartOffset then
    ContextEndOffset := ContextStartOffset;

  ReadOffset := ContextStartOffset;
  ReadLength := ContextEndOffset - ContextStartOffset;
  if ReadLength <= 0 then
    Exit;

  Buffer := FFileHandler.ReadBytes(ReadOffset, ReadLength);
  ContextText := '';
  CurrentOffset := ReadOffset;
  MarkerInserted := False;
  ContextStartCut := ContextStartOffset > LineStartOffset;
  ContextEndCut := False;
  BufferIndex := 0;

  while BufferIndex < Length(Buffer) do
  begin
    if (not MarkerInserted) and (CurrentOffset >= ErrorOffset) then
    begin
      ContextText := ContextText + MarkerText;
      MarkerInserted := True;
    end;

    if Encoding = jeUTF8 then
    begin
      CharValue := Buffer[BufferIndex];
      Inc(BufferIndex);
      Inc(CurrentOffset);
    end
    else
    begin
      if BufferIndex + 1 >= Length(Buffer) then
        Break;
      if Encoding = jeUTF16LE then
        CharValue := Buffer[BufferIndex] or (Buffer[BufferIndex + 1] shl 8)
      else
        CharValue := (Buffer[BufferIndex] shl 8) or Buffer[BufferIndex + 1];
      Inc(BufferIndex, 2);
      Inc(CurrentOffset, 2);
    end;

    if CharValue in [10, 13] then
    begin
      if CurrentOffset > ErrorOffset then
      begin
        ContextEndCut := True;
        Break;
      end;
      Continue;
    end;

    AppendVisibleChar(CharValue);

    if Length(ContextText) >= (ContextCharsBefore + ContextCharsAfter + Length(MarkerText) + 20) then
    begin
      ContextEndCut := True;
      Break;
    end;
  end;

  if not MarkerInserted then
    ContextText := ContextText + MarkerText;

  ContextText := Trim(ContextText);
  if ContextStartCut then
    ContextText := '...' + ContextText;
  if ContextEndCut then
    ContextText := ContextText + '...';

  if ContextText = '' then
    Exit;

  AContext := Format('Line %d'#13#10'Near: %s', [LineNumber, ContextText]);
  Result := True;
end;

function TFrmMain.IsClipboardTempFile(const AFileName: string): Boolean;
begin
  Result := Pos('lazjson_clipboard_', ExtractFileName(AFileName)) = 1;
end;

function TFrmMain.GetEmptyJSONMessage(const AFileName: string): string;
begin
  if IsClipboardTempFile(AFileName) then
    Result := 'Clipboard has empty JSON.'
  else
    Result := 'File has empty JSON.';
end;

function TFrmMain.GetPreferencesFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(GetAppConfigFolder) + PREFERENCES_CFG;
end;

function TFrmMain.TryGetFileChangeSignature(const AFileName: string; out ASignature: string): Boolean;
var
  SearchRec: TSearchRec;
begin
  Result := False;
  ASignature := '';

  if Trim(AFileName) = '' then
    Exit;

  try
    if FindFirst(AFileName, faAnyFile, SearchRec) = 0 then
    begin
      try
        ASignature := IntToStr(SearchRec.Time) + ':' + IntToStr(SearchRec.Size);
        Result := True;
      finally
        FindClose(SearchRec);
      end;
    end;
  except
    Result := False;
  end;
end;

function TFrmMain.IsWatchableFile(const AFileName: string): Boolean;
var
  BaseName: string;
begin
  BaseName := ExtractFileName(AFileName);
  Result := (AFileName <> '') and
            FileExists(AFileName) and
            (Pos('lazjson_clipboard_', BaseName) = 0) and
            (Pos('lazjson_url_', BaseName) = 0);
end;

function TFrmMain.IsJSONFileAssociated: Boolean;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  ProgId: string;
  OpenCommand: string;
  IconValue: string;
  AssociationSelected: Boolean;
{$ENDIF}
begin
  Result := False;
  {$IFDEF WINDOWS}
  Reg := TRegistry.Create(KEY_READ);
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    AssociationSelected := False;

    if Reg.OpenKey('\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts\.json\UserChoice', False) then
    begin
      try
        ProgId := Reg.ReadString('Progid');
      except
        ProgId := '';
      end;
      Reg.CloseKey;
      if SameText(ProgId, JSON_FILE_PROGID) then
        AssociationSelected := True;
    end;

    if (not AssociationSelected) and Reg.OpenKey('\Software\Classes\.json', False) then
    begin
      try
        ProgId := Reg.ReadString('');
      except
        ProgId := '';
      end;
      Reg.CloseKey;
      AssociationSelected := SameText(ProgId, JSON_FILE_PROGID);
    end;

    if not AssociationSelected then
      Exit(False);

    OpenCommand := '';
    if Reg.OpenKey('\Software\Classes\' + JSON_FILE_PROGID + '\shell\open\command', False) then
    begin
      try
        OpenCommand := Reg.ReadString('');
      except
        OpenCommand := '';
      end;
      Reg.CloseKey;
    end;

    IconValue := '';
    if Reg.OpenKey('\Software\Classes\' + JSON_FILE_PROGID + '\DefaultIcon', False) then
    begin
      try
        IconValue := Reg.ReadString('');
      except
        IconValue := '';
      end;
      Reg.CloseKey;
    end;

    Result := SameText(Trim(OpenCommand), '"' + Application.ExeName + '" "%1"') and
      SameText(Trim(StringReplace(IconValue, '"', '', [rfReplaceAll])), GetJSONAssociationIconPath);
  finally
    Reg.Free;
  end;
  {$ENDIF}
end;

function TFrmMain.TrySetJSONFileAssociation(out AErrorMessage: string): Boolean;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  ExePath: string;
  AppFileName: string;
  IconPath: string;
{$ENDIF}
begin
  Result := False;
  AErrorMessage := 'JSON file association is available only on Windows.';

  {$IFDEF WINDOWS}
  AErrorMessage := '';
  ExePath := Application.ExeName;
  AppFileName := ExtractFileName(ExePath);
  IconPath := GetJSONAssociationIconPath;
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    if not Reg.OpenKey('\Software\Classes\' + JSON_FILE_PROGID, True) then
    begin
      AErrorMessage := 'Unable to create the JSON file association.';
      Exit;
    end;
    Reg.WriteString('', 'JSON File');
    Reg.CloseKey;

    if not Reg.OpenKey('\Software\Classes\' + JSON_FILE_PROGID + '\DefaultIcon', True) then
    begin
      AErrorMessage := 'Unable to register the JSON file icon.';
      Exit;
    end;
    Reg.WriteString('', IconPath);
    Reg.CloseKey;

    if not Reg.OpenKey('\Software\Classes\' + JSON_FILE_PROGID + '\shell\open\command', True) then
    begin
      AErrorMessage := 'Unable to register the JSON open command.';
      Exit;
    end;
    Reg.WriteString('', '"' + ExePath + '" "%1"');
    Reg.CloseKey;

    if not Reg.OpenKey('\Software\Classes\.json', True) then
    begin
      AErrorMessage := 'Unable to register the .json extension.';
      Exit;
    end;
    Reg.WriteString('', JSON_FILE_PROGID);
    Reg.CloseKey;

    if not Reg.OpenKey('\Software\Classes\.json\OpenWithProgids', True) then
    begin
      AErrorMessage := 'Unable to register JSON Open With support.';
      Exit;
    end;
    if not Reg.ValueExists(JSON_FILE_PROGID) then
      Reg.WriteString(JSON_FILE_PROGID, '');
    Reg.CloseKey;

    if not Reg.OpenKey('\Software\Classes\Applications\' + AppFileName + '\shell\open\command', True) then
    begin
      AErrorMessage := 'Unable to register the application command.';
      Exit;
    end;
    Reg.WriteString('', '"' + ExePath + '" "%1"');
    Reg.CloseKey;

    if not Reg.OpenKey('\Software\Classes\Applications\' + AppFileName + '\SupportedTypes', True) then
    begin
      AErrorMessage := 'Unable to register supported file types.';
      Exit;
    end;
    if not Reg.ValueExists('.json') then
      Reg.WriteString('.json', '');
    Reg.CloseKey;

    if Reg.OpenKey('\Software\Classes\Applications\' + AppFileName + '\DefaultIcon', True) then
    begin
      Reg.WriteString('', IconPath);
      Reg.CloseKey;
    end;

    Result := True;
  except
    on E: Exception do
      AErrorMessage := 'Unable to update JSON file association: ' + E.Message;
  end;
  Reg.Free;
  {$ENDIF}
end;

function TFrmMain.TryRemoveJSONFileAssociation(out AErrorMessage: string): Boolean;
{$IFDEF WINDOWS}
var
  Reg: TRegistry;
  ProgId: string;
  AppFileName: string;
{$ENDIF}
begin
  Result := False;
  AErrorMessage := 'JSON file association is available only on Windows.';

  {$IFDEF WINDOWS}
  AErrorMessage := '';
  AppFileName := ExtractFileName(Application.ExeName);
  Reg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Reg.RootKey := HKEY_CURRENT_USER;

    ProgId := '';
    if Reg.OpenKey('\Software\Classes\.json', False) then
    begin
      try
        ProgId := Reg.ReadString('');
      except
        ProgId := '';
      end;
      Reg.CloseKey;
    end;

    if SameText(ProgId, JSON_FILE_PROGID) and Reg.OpenKey('\Software\Classes\.json', False) then
    begin
      Reg.DeleteValue('');
      Reg.CloseKey;
    end;

    if Reg.KeyExists('\Software\Classes\.json\OpenWithProgids') and
       Reg.OpenKey('\Software\Classes\.json\OpenWithProgids', False) then
    begin
      if Reg.ValueExists(JSON_FILE_PROGID) then
        Reg.DeleteValue(JSON_FILE_PROGID);
      Reg.CloseKey;
    end;

    if Reg.KeyExists('\Software\Classes\' + JSON_FILE_PROGID) then
      Reg.DeleteKey('\Software\Classes\' + JSON_FILE_PROGID);

    if Reg.KeyExists('\Software\Classes\Applications\' + AppFileName) then
      Reg.DeleteKey('\Software\Classes\Applications\' + AppFileName);

    Result := True;
  except
    on E: Exception do
      AErrorMessage := 'Unable to remove JSON file association: ' + E.Message;
  end;
  Reg.Free;
  {$ENDIF}
end;

procedure TFrmMain.LoadPreferences;
var
  Ini: TIniFile;
  StoredMode: Integer;
begin
  FAutoRefreshMode := armAsk;

  if not FileExists(GetPreferencesFileName) then
    Exit;

  Ini := TIniFile.Create(GetPreferencesFileName);
  try
    StoredMode := Ini.ReadInteger(PREF_SECTION_GENERAL, PREF_KEY_AUTO_REFRESH, Ord(armAsk));
    FAlwaysOnTop := Ini.ReadBool(PREF_SECTION_GENERAL, PREF_KEY_ALWAYS_ON_TOP, False);
    if StoredMode < Ord(Low(TAutoRefreshMode)) then
      StoredMode := Ord(armAsk)
    else if StoredMode > Ord(High(TAutoRefreshMode)) then
      StoredMode := Ord(armAsk);
    FAutoRefreshMode := TAutoRefreshMode(StoredMode);
  finally
    Ini.Free;
  end;
end;

procedure TFrmMain.SavePreferences;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(GetPreferencesFileName);
  try
    Ini.WriteInteger(PREF_SECTION_GENERAL, PREF_KEY_AUTO_REFRESH, Ord(FAutoRefreshMode));
    Ini.WriteBool(PREF_SECTION_GENERAL, PREF_KEY_ALWAYS_ON_TOP, FAlwaysOnTop);
  finally
    Ini.Free;
  end;
end;

procedure TFrmMain.ApplyAlwaysOnTop;
begin
  if FSessionAlwaysOnTop then
    FormStyle := fsSystemStayOnTop
  else
    FormStyle := fsNormal;

  UpdateAlwaysOnTopMenuState;
end;

procedure TFrmMain.UpdateAlwaysOnTopMenuState;
begin
  if FAlwaysOnTopMenuItem <> nil then
    FAlwaysOnTopMenuItem.Checked := FSessionAlwaysOnTop;
end;

procedure TFrmMain.UpdateCurrentFileSignature;
begin
  if not IsWatchableFile(FCurrentFileName) then
  begin
    FCurrentFileSignature := '';
    FPendingFileChange := False;
    Exit;
  end;

  if not TryGetFileChangeSignature(FCurrentFileName, FCurrentFileSignature) then
    FCurrentFileSignature := '';

  FPendingFileChange := False;
end;

procedure TFrmMain.ReloadCurrentFile;
var
  FileName: string;
begin
  FileName := FCurrentFileName;
  if FileName = '' then
    Exit;

  if not FileExists(FileName) then
  begin
    MessageDlg('File Missing',
      'The file no longer exists on disk.' + LineEnding + LineEnding + FileName,
      mtWarning, [mbOK], 0);
    CloseCurrentFile;
    Exit;
  end;

  LoadFile(FileName);
end;

function TFrmMain.ConfirmLargeFileRefresh: Boolean;
var
  FileSizeBytes: Int64;
begin
  Result := True;
  FileSizeBytes := 0;

  try
    if Assigned(FFileHandler) and FFileHandler.IsOpen then
      FileSizeBytes := FFileHandler.FileSize;
  except
    FileSizeBytes := 0;
  end;

  if FileSizeBytes < LARGE_FILE_REFRESH_CONFIRM_BYTES then
    Exit;

  Result := MessageDlg(
    'Refresh Large File',
    'This file is ' + FormatByteSize(FileSizeBytes) + '.' + LineEnding + LineEnding +
    'Do you want to reload it now?',
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) = mrYes;
end;

procedure TFrmMain.ToggleAlwaysOnTopClick(Sender: TObject);
begin
  FSessionAlwaysOnTop := not FSessionAlwaysOnTop;
  ApplyAlwaysOnTop;
end;

procedure TFrmMain.QueueStartupFile(const AFileName: string);
begin
  FStartupFileName := Trim(AFileName);
  FStartupFilePending := FStartupFileName <> '';
end;

procedure TFrmMain.HandleDetectedFileChange(AFromActivation: Boolean);
begin
  if not FPendingFileChange then
    Exit;

  case FAutoRefreshMode of
    armNever:
      FPendingFileChange := False;
    armAsk:
      begin
        if not AFromActivation and (Screen.ActiveForm <> Self) then
          Exit;

        if MessageDlg('File Changed',
          'The file changed on disk.' + LineEnding + LineEnding + 'Reload it now?',
          mtConfirmation, [mbYes, mbNo], 0) = mrYes then
          ReloadCurrentFile;

        FPendingFileChange := False;
      end;
    armOnFocus:
      begin
        if not AFromActivation then
          Exit;
        ReloadCurrentFile;
        FPendingFileChange := False;
      end;
    armAlways:
      begin
        ReloadCurrentFile;
        FPendingFileChange := False;
      end;
  end;
end;

procedure TFrmMain.OnFileWatchTimer(Sender: TObject);
var
  NewSignature: string;
begin
  if (Screen.Cursor = crHourGlass) or
     (FVirtualTree = nil) or
     FVirtualTree.ParsingInProgress or
     (not IsWatchableFile(FCurrentFileName)) then
    Exit;

  if not TryGetFileChangeSignature(FCurrentFileName, NewSignature) then
    Exit;

  if FCurrentFileSignature = '' then
  begin
    FCurrentFileSignature := NewSignature;
    Exit;
  end;

  if NewSignature <> FCurrentFileSignature then
  begin
    FCurrentFileSignature := NewSignature;
    FPendingFileChange := True;
    HandleDetectedFileChange(False);
  end;
end;

{ ══════════════════════════════════════════════════════════════════════
  UI COMPONENT CREATION (Programmatic — avoids .lfm sync issues)
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.CreateUIComponents;
begin
  { ── Welcome label (shown when no file is loaded) ──────── }
  FWelcomeLabel := TLabel.Create(Self);
  FWelcomeLabel.Parent := pnlTreeViewContainer;
  FWelcomeLabel.Align := alClient;
  FWelcomeLabel.Alignment := taCenter;
  FWelcomeLabel.Layout := tlCenter;
  FWelcomeLabel.WordWrap := True;
  FWelcomeLabel.Font.Color := clGray;
  FWelcomeLabel.Font.Size := 11;
  FWelcomeLabel.Caption := 'Welcome to Large JSON Viewer.' + LineEnding +
    'Open, paste or drag and drop .json file here.';
  FWelcomeLabel.Visible := True;

  { ── TreeView (full width style) ────────────── }
  pnlTreeViewContainer.Align := alClient;
  
  { Create Context Menu }
  popTree := TPopupMenu.Create(Self);
  
  popCopyName := TMenuItem.Create(popTree);
  popCopyName.Caption := 'Copy Name';
  popCopyName.OnClick := @popCopyNameClick;
  popTree.Items.Add(popCopyName);
  
  popCopyValue := TMenuItem.Create(popTree);
  popCopyValue.Caption := 'Copy Value';
  popCopyValue.OnClick := @popCopyValueClick;
  popTree.Items.Add(popCopyValue);
  
  popCopyValueAs := TMenuItem.Create(popTree);
  popCopyValueAs.Caption := 'Copy Value As';
  popTree.Items.Add(popCopyValueAs);
  
  popCopyMinifiedValue := TMenuItem.Create(popTree);
  popCopyMinifiedValue.Caption := 'Minified Value';
  popCopyMinifiedValue.OnClick := @popCopyMinifiedValueClick;
  popCopyValueAs.Add(popCopyMinifiedValue);
  
  popCopyFormattedValue := TMenuItem.Create(popTree);
  popCopyFormattedValue.Caption := 'Formatted Value';
  popCopyFormattedValue.OnClick := @popCopyFormattedValueClick;
  popCopyValueAs.Add(popCopyFormattedValue);
  
  popCopyPath := TMenuItem.Create(popTree);
  popCopyPath.Caption := 'Copy Path';
  popCopyPath.OnClick := @popCopyPathClick;
  popTree.Items.Add(popCopyPath);
  
  popSeparator1 := TMenuItem.Create(popTree);
  popSeparator1.Caption := '-';
  popTree.Items.Add(popSeparator1);
  
  popExportValueAs := TMenuItem.Create(popTree);
  popExportValueAs.Caption := 'Export Value As';
  popTree.Items.Add(popExportValueAs);
  
  popExportJSON := TMenuItem.Create(popTree);
  popExportJSON.Caption := 'JSON';
  popExportJSON.OnClick := @popExportJSONClick;
  popExportValueAs.Add(popExportJSON);
  
  popExportMinifiedJSON := TMenuItem.Create(popTree);
  popExportMinifiedJSON.Caption := 'Minified JSON';
  popExportMinifiedJSON.OnClick := @popExportMinifiedJSONClick;
  popExportValueAs.Add(popExportMinifiedJSON);
  
  popExportFormattedJSON := TMenuItem.Create(popTree);
  popExportFormattedJSON.Caption := 'Formatted JSON';
  popExportFormattedJSON.OnClick := @popExportFormattedJSONClick;
  popExportValueAs.Add(popExportFormattedJSON);
  
  popSeparator2 := TMenuItem.Create(popTree);
  popSeparator2.Caption := '-';
  popExportValueAs.Add(popSeparator2);
  
  popExportMinifiedXML := TMenuItem.Create(popTree);
  popExportMinifiedXML.Caption := 'Minified XML';
  popExportMinifiedXML.OnClick := @popExportMinifiedXMLClick;
  popExportValueAs.Add(popExportMinifiedXML);
  
  popExportFormattedXML := TMenuItem.Create(popTree);
  popExportFormattedXML.Caption := 'Formatted XML';
  popExportFormattedXML.OnClick := @popExportFormattedXMLClick;
  popExportValueAs.Add(popExportFormattedXML);

  popSeparator3 := TMenuItem.Create(popTree);
  popSeparator3.Caption := '-';
  popExportValueAs.Add(popSeparator3);

  popExportCSV := TMenuItem.Create(popTree);
  popExportCSV.Caption := 'CSV';
  popExportCSV.OnClick := @popExportCSVClick;
  popExportValueAs.Add(popExportCSV);

  popExportYAML := TMenuItem.Create(popTree);
  popExportYAML.Caption := 'YAML';
  popExportYAML.OnClick := @popExportYAMLClick;
  popExportValueAs.Add(popExportYAML);

  popExportTOML := TMenuItem.Create(popTree);
  popExportTOML.Caption := 'TOML';
  popExportTOML.OnClick := @popExportTOMLClick;
  popExportValueAs.Add(popExportTOML);

  FAlwaysOnTopMenuItem := TMenuItem.Create(mnuView);
  FAlwaysOnTopMenuItem.Caption := 'Always on Top';
  FAlwaysOnTopMenuItem.AutoCheck := False;
  FAlwaysOnTopMenuItem.OnClick := @ToggleAlwaysOnTopClick;
  mnuView.Add(FAlwaysOnTopMenuItem);

  FTreeView := TVirtualStringTree.Create(Self);
  FTreeView.Parent := pnlTreeViewContainer;
  FTreeView.Align := alClient;
  FTreeView.BorderStyle := bsNone;
  FTreeView.PopupMenu := popTree;
  
  FTreeView.Font.Name := 'Consolas';
  FTreeView.Font.Size := 10;
  FTreeView.Visible := False;

  { ── Hide detail panel (full-width tree) ────── }
  Panel1.Visible := False;

  { ── Detail components (hidden but available) ────────── }
  FSplitter := nil;
  FDetailHeaderLabel := TLabel.Create(Self);
  FDetailHeaderLabel.Parent := Panel1;
  FDetailHeaderLabel.Visible := False;

  FDetailMemo := TMemo.Create(Self);
  FDetailMemo.Parent := Panel1;
  FDetailMemo.Visible := False;
end;

{ ══════════════════════════════════════════════════════════════════════
  SUBSYSTEM MANAGEMENT
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.InitializeSubsystems;
begin
  FFileHandler := TFileHandler.Create;
  FIndex := TJSONIndex.Create;
  FStringPool := TStringPool.Create;
  FNodeCache := TNodeCache.Create;

  FSearchEngine := TSearchEngine.Create(FIndex, FFileHandler, FNodeCache, FStringPool);
  FPathBuilder := TJSONPathBuilder.Create(FIndex, FFileHandler, FStringPool);

  FVirtualTree := TVirtualJSONTree.Create(FTreeView, FIndex, FFileHandler,
    FNodeCache, FStringPool);
  FVirtualTree.OnNodeSelected := @OnTreeNodeSelected;

  FStatusManager := TStatusManager.Create(StatusBar1, StatusBar2);
end;

procedure TFrmMain.DestroySubsystems;
begin
  FreeAndNil(FVirtualTree);
  FreeAndNil(FStatusManager);
  FreeAndNil(FSearchEngine);
  FreeAndNil(FPathBuilder);
  FreeAndNil(FNodeCache);
  FreeAndNil(FStringPool);
  FreeAndNil(FIndex);
  FreeAndNil(FFileHandler);
end;

{ ══════════════════════════════════════════════════════════════════════
  FILE LOADING
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.LoadFile(const AFileName: string);
var
  Thread: TParseThread;
begin
  { Prevent multiple loads }
  if Screen.Cursor = crHourGlass then Exit;

  Screen.Cursor := crHourGlass;
  try
    CloseCurrentFile;
    FCurrentFileName := AFileName;
    
    // Add to recent files only if it's a real file (not a temp URL/clipboard file)
    if (Pos('lazjson_url_', ExtractFileName(AFileName)) = 0) and
       (Pos('lazjson_clipboard_', ExtractFileName(AFileName)) = 0) then
    begin
      AddRecentFile(AFileName);
    end;

    UpdateTitle;

    FStatusManager.SetProgress('Opening file...', 0);
    FFileHandler.OpenFile(AFileName);
    UpdateCurrentFileSignature;

    if FFileHandler.FileSize = 0 then
    begin
      Screen.Cursor := crDefault;
      MessageDlg('Empty JSON', GetEmptyJSONMessage(AFileName), mtInformation, [mbOK], 0);
      CloseCurrentFile;
      Exit;
    end;

    FStatusManager.SetProgress(
      Format('File opened (%s) — Spawning thread...', [FormatByteSize(FFileHandler.FileSize)]),
      1);

    { Start background parsing thread }
    FVirtualTree.ParsingInProgress := True;
    Thread := TParseThread.Create(Self, AFileName, FIndex, FStringPool);
    Thread.Start;
  except
    on E: Exception do
    begin
      Screen.Cursor := crDefault;
      FStatusManager.SetNodePath('Error: ' + E.Message);
      MessageDlg('Error Loading File',
        Format('Failed to open "%s":'#13#10#13#10'%s',
          [ExtractFileName(AFileName), E.Message]),
        mtError, [mbOK], 0);
      CloseCurrentFile;
    end;
  end;
end;

procedure TFrmMain.OnParseCompleted(const AFileName: string; ElapsedMs: Int64; const AWarning: string = '');
var
  FriendlyWarning: string;
begin
  FVirtualTree.ParsingInProgress := False;
  FStatusManager.SetProgress('Building tree view...', 95);

  if FTreeView.RootNodeCount = 0 then
    FVirtualTree.BuildRootNodes
  else
    FVirtualTree.UpdateRootCount;

  FWelcomeLabel.Visible := False;
  FTreeView.Visible := True;

  FStatusManager.SetFileInfo(AFileName, FFileHandler.FileSize, FIndex.Count, ElapsedMs);
  FStatusManager.SetMemoryUsage(FNodeCache.CurrentSizeBytes + (Int64(FIndex.Count) * SizeOf(TJSONIndexEntry)));
  FStatusManager.SetReady;
  UpdateCurrentFileSignature;
  
  Screen.Cursor := crDefault;

  if AWarning <> '' then
  begin
    FriendlyWarning := StripParseByteOffset(AWarning);
    if TryBuildParseErrorContext(AWarning, FriendlyWarning) then
      FriendlyWarning := StripParseByteOffset(AWarning) + LineEnding + LineEnding + FriendlyWarning
    else
      FriendlyWarning := StripParseByteOffset(AWarning);

    MessageDlg('Partial JSON Loaded',
      'The file contained invalid JSON and could not be fully parsed.' + LineEnding + LineEnding +
      'Loaded up to the error.' + LineEnding + LineEnding +
      'Error: ' + FriendlyWarning,
      mtWarning, [mbOK], 0);
  end;
end;

procedure TFrmMain.OnParseError(const AFileName: string; const ErrorMsg: string);
var
  FriendlyError: string;
begin
  FVirtualTree.ParsingInProgress := False;
  Screen.Cursor := crDefault;
  FStatusManager.SetNodePath('Error: ' + ErrorMsg);
  
  // Show a clean user-friendly message for invalid JSON without scary offsets if possible
  if Pos('Empty JSON document', ErrorMsg) > 0 then
    MessageDlg('Empty JSON',
      GetEmptyJSONMessage(AFileName),
      mtInformation, [mbOK], 0)
  else if Pos('does not start with a valid JSON value', ErrorMsg) > 0 then
    MessageDlg('Invalid JSON',
      'It is not a valid JSON.',
      mtWarning, [mbOK], 0)
  else if Pos('JSON Parse Error:', ErrorMsg) > 0 then
  begin
    FriendlyError := StripParseByteOffset(ErrorMsg);
    if TryBuildParseErrorContext(ErrorMsg, FriendlyError) then
      FriendlyError := StripParseByteOffset(ErrorMsg) + #13#10#13#10 + FriendlyError
    else
      FriendlyError := StripParseByteOffset(ErrorMsg);

    MessageDlg('Invalid JSON',
      'It is not a valid JSON.'#13#10#13#10'Details: ' + FriendlyError,
      mtWarning, [mbOK], 0);
  end
  else
    MessageDlg('Error Parsing File',
      Format('Failed to parse "%s":'#13#10#13#10'%s',
        [ExtractFileName(AFileName), ErrorMsg]),
      mtError, [mbOK], 0);
      
  CloseCurrentFile;
end;

procedure TFrmMain.CloseCurrentFile;
begin
  FSearchEngine.ClearResults;
  FVirtualTree.ParsingInProgress := False;
  FVirtualTree.Clear;
  FNodeCache.Clear;
  FIndex.Clear;
  FStringPool.Clear;
  FFileHandler.CloseFile;
  FDetailMemo.Clear;
  FDetailHeaderLabel.Caption := ' Node Details';
  FCurrentFileSignature := '';
  FPendingFileChange := False;
  FCurrentFileName := '';
  edtSearch.Text := '';
  UpdateTitle;
  FTreeView.Visible := False;
  FWelcomeLabel.Visible := True;
end;

{ ══════════════════════════════════════════════════════════════════════
  DETAIL PANEL
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.UpdateDetailPanel;
var
  Data: TJSONNodeData;
  Path: string;
  Lines: TStringList;
begin
  if FVirtualTree.SelectedNodeIndex < 0 then
  begin
    FDetailMemo.Clear;
    FDetailHeaderLabel.Caption := ' Node Details';
    FStatusManager.SetNodePath('$');
    Exit;
  end;

  Data := FVirtualTree.GetSelectedNodeData;
  Path := FPathBuilder.BuildPath(FVirtualTree.SelectedNodeIndex);

  { Update path bar }
  FStatusManager.SetNodePath(Path);

  { Update detail header }
  FDetailHeaderLabel.Caption := Format(' %s (%s)',
    [JSONNodeTypeToStr(Data.NodeType), FormatByteSize(Data.SizeBytes)]);

  { Build detail view }
  Lines := TStringList.Create;
  try
    Lines.Add('━━━ Node Information ━━━');
    Lines.Add('');
    Lines.Add('Path:       ' + Path);
    Lines.Add('Type:       ' + JSONNodeTypeToStr(Data.NodeType));

    if Data.Key <> '' then
      Lines.Add('Key:        ' + Data.Key);

    if Data.ArrayIndex >= 0 then
      Lines.Add('Index:      ' + IntToStr(Data.ArrayIndex));

    Lines.Add('Size:       ' + FormatByteSize(Data.SizeBytes));

    if Data.ChildCount > 0 then
      Lines.Add('Children:   ' + FormatFloat('#,##0', Data.ChildCount));

    Lines.Add('Depth:      ' + IntToStr(Data.Depth));
    Lines.Add('');
    Lines.Add('━━━ Value ━━━');
    Lines.Add('');

    case Data.NodeType of
      jntObject, jntArray:
        Lines.Add(Data.Value);
      jntString:
      begin
        Lines.Add('"' + Data.FullValue + '"');
        Lines.Add('');
        Lines.Add('(String length: ' + IntToStr(Length(Data.FullValue)) + ' chars)');
      end;
    else
      Lines.Add(Data.FullValue);
    end;

    FDetailMemo.Lines.Assign(Lines);
  finally
    Lines.Free;
  end;
end;

procedure TFrmMain.UpdateTitle;
begin
  if FCurrentFileName <> '' then
    Caption := Format('%s — %s', [ExtractFileName(FCurrentFileName), APP_TITLE])
  else
    Caption := APP_TITLE;
end;

{ ══════════════════════════════════════════════════════════════════════
  CALLBACKS
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.OnTreeNodeSelected(Sender: TObject);
begin
  UpdateDetailPanel;
end;


{ ══════════════════════════════════════════════════════════════════════
  SEARCH
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.OnSearchDebounce(Sender: TObject);
begin
  FSearchDebounceTimer.Enabled := False;
  ExecuteSearch;
end;

procedure TFrmMain.ExecuteSearch;
var
  Query: string;
begin
  Query := Trim(edtSearch.Text);

  { If there's an active search thread, cancel the underlying search engine. }
  if Assigned(FSearchThread) then
  begin
    FSearchEngine.Cancel;
    FSearchThread := nil;
  end;

  if Query = '' then
  begin
    FSearchEngine.ClearResults;
    FStatusManager.SetSearchInfo('');
    Exit;
  end;

  Screen.Cursor := crHourGlass;
  FStatusManager.SetSearchInfo('Searching...');

  { Spawn the search thread to do the work without blocking the UI }
  FSearchThread := TSearchThread.Create(Self, FSearchEngine, Query, FCaseSensitive, FUseRegEx);
  FSearchThread.Start;
end;

procedure TFrmMain.NavigateToSearchResult(ANodeIndex: Integer);
begin
  if ANodeIndex < 0 then Exit;
  FVirtualTree.NavigateToNode(ANodeIndex);
  FStatusManager.SetSearchInfo(FSearchEngine.GetResultInfo);
end;

{ ══════════════════════════════════════════════════════════════════════
  EXPORT
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.ExportToFile(const AData: string; AFormat: TExportFormat);
var
  SaveDlg: TSaveDialog;
begin
  SaveDlg := TSaveDialog.Create(Self);
  try
    SaveDlg.Options := SaveDlg.Options + [ofNoTestFileCreate, ofOverwritePrompt];
    SaveDlg.Filter := TDataExporter.GetFilter(AFormat);
    SaveDlg.DefaultExt := TDataExporter.GetDefaultExtension(AFormat);
    SaveDlg.FileName := ChangeFileExt(ExtractFileName(FCurrentFileName), '.' + SaveDlg.DefaultExt);

    if SaveDlg.Execute then
    begin
      try
        TDataExporter.ExportToFile(AData, AFormat, SaveDlg.FileName);
        FStatusManager.SetNodePath('Exported to: ' + SaveDlg.FileName);
      except
        on E: Exception do
          MessageDlg('Export Error', E.Message, mtError, [mbOK], 0);
      end;
    end;
  finally
    SaveDlg.Free;
  end;
end;

{ ══════════════════════════════════════════════════════════════════════
  MENU EVENT HANDLERS — File
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.mnuFileClick(Sender: TObject);
begin
  { Update menu item states }
  mnuExportAs.Enabled := FCurrentFileName <> '';
  mnuExportSectionAs.Enabled := FVirtualTree.SelectedNodeIndex >= 0;
end;

procedure TFrmMain.mnuNewWindowClick(Sender: TObject);
begin
  { Launch a new instance of the application }
  {$IFDEF WINDOWS}
  SysUtils.ExecuteProcess(Application.ExeName, '', []);
  {$ENDIF}
end;

procedure TFrmMain.mnuOpenClick(Sender: TObject);
begin
  if actFileOpen.Dialog.FileName <> '' then
    LoadFile(actFileOpen.Dialog.FileName);
end;

procedure TFrmMain.mnuOpenFolderClick(Sender: TObject);
var
  Dir: string;
  OpenDlg: TOpenDialog;
begin
  if SelectDirectory('Select Folder Containing JSON Files', '', Dir) then
  begin
    OpenDlg := TOpenDialog.Create(Self);
    try
      OpenDlg.InitialDir := Dir;
      OpenDlg.Filter := 'JSON Files (*.json)|*.json|All Files (*.*)|*.*';
      OpenDlg.Title := 'Select a JSON file to open';
      if OpenDlg.Execute then
      begin
        LoadFile(OpenDlg.FileName);
      end;
    finally
      OpenDlg.Free;
    end;
  end;
end;

procedure TFrmMain.OnDownloadProgress(const Msg: string; Percent: Integer);
begin
  FStatusManager.SetProgress(Msg, Percent);
end;

function GetBaseAppConfigFolder: string;
begin
  Result := ExtractFileDir(ExcludeTrailingPathDelimiter(GetAppConfigDir(False)));
end;

function GetAppConfigFolder: string;
begin
  Result := IncludeTrailingPathDelimiter(GetBaseAppConfigFolder) + 'LargeJSONViewer';
  Result := IncludeTrailingPathDelimiter(Result);
  if not DirectoryExists(Result) then
    ForceDirectories(Result);
end;

function GetJSONAssociationIconPath: string;
begin
  Result := Application.ExeName + ',-' + IntToStr(JSON_FILE_ICON_RESOURCE_ID);
end;

function GetLegacyAppConfigFolder: string;
begin
  Result := GetAppConfigDir(False);
end;

function TryLoadRecentFilesFromPath(const AFileName: string; ARecentFiles: TStringList): Boolean;
var
  FS: TFileStream;
  I: Integer;
begin
  Result := False;
  if (ARecentFiles = nil) or (not FileExists(AFileName)) then
    Exit;

  ARecentFiles.Clear;

  try
    FS := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    try
      ARecentFiles.LoadFromStream(FS);
    finally
      FS.Free;
    end;
  except
    try
      ARecentFiles.LoadFromFile(AFileName);
    except
      ARecentFiles.Clear;
      Exit;
    end;
  end;

  for I := ARecentFiles.Count - 1 downto 0 do
  begin
    ARecentFiles[I] := Trim(ARecentFiles[I]);
    if ARecentFiles[I] = '' then
      ARecentFiles.Delete(I);
  end;

  Result := ARecentFiles.Count > 0;
end;

procedure TFrmMain.OnDownloadComplete(const TempFile: string);
begin
  Screen.Cursor := crDefault;
  if not FileExists(TempFile) then
  begin
    FStatusManager.SetReady;
    MessageDlg('Download Error', 'The downloaded file could not be found.', mtError, [mbOK], 0);
    Exit;
  end;

  FStatusManager.SetProgress('Opening downloaded file...', 100);
  LoadFile(TempFile);
end;

procedure TFrmMain.OnDownloadError(const ErrorMsg: string);
begin
  Screen.Cursor := crDefault;
  FStatusManager.SetReady;
  MessageDlg('Download Error', ErrorMsg, mtError, [mbOK], 0);
end;

procedure TFrmMain.mnuOpenURLClick(Sender: TObject);
var
  URL: string;
  TempFile: string;
  DownloadThread: TDownloadThread;
begin
  FrmOpenURL := TFrmOpenURL.Create(Self);
  try
    if FrmOpenURL.ShowModal = mrOk then
    begin
      URL := FrmOpenURL.GetURL;
      if Trim(URL) = '' then Exit;

      if not (LowerCase(Copy(URL, 1, 7)) = 'http://') and not (LowerCase(Copy(URL, 1, 8)) = 'https://') then
        URL := 'http://' + URL;

      FStatusManager.SetProgress('Connecting...', 0);
      Screen.Cursor := crHourGlass;
      
      // Use AppData for temporary download files to avoid %temp% permission issues
      TempFile := IncludeTrailingPathDelimiter(GetAppConfigFolder) + 'lazjson_url_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.json';
      DownloadThread := TDownloadThread.Create(URL, TempFile, FrmOpenURL.GetAuthType, 
        FrmOpenURL.GetToken, FrmOpenURL.GetUsername, FrmOpenURL.GetPassword);
      DownloadThread.OnProgress := @OnDownloadProgress;
      DownloadThread.OnComplete := @OnDownloadComplete;
      DownloadThread.OnError := @OnDownloadError;
      DownloadThread.Start;
    end;
  finally
    FrmOpenURL.Free;
  end;
end;

procedure TFrmMain.mnuPasteClipboardClick(Sender: TObject);
var
  ClipText: string;
  TempFile: string;
  FirstChar: Char;
  I: Integer;
begin
  ClipText := Clipboard.AsText;
  if Trim(ClipText) = '' then
  begin
    MessageDlg('Empty JSON', 'Clipboard has empty JSON.', mtInformation, [mbOK], 0);
    Exit;
  end;

  { Quick validation before creating a temp file }
  FirstChar := #0;
  for I := 1 to Length(ClipText) do
  begin
    if not (ClipText[I] in [#9, #10, #13, #32]) then
    begin
      FirstChar := ClipText[I];
      Break;
    end;
  end;

  if not (FirstChar in ['{', '[', '"', 't', 'f', 'n', '-', '0'..'9']) then
  begin
    MessageDlg('Invalid JSON', 'It is not a valid JSON.', mtWarning, [mbOK], 0);
    Exit;
  end;

  { Save to temp file and load }
  TempFile := IncludeTrailingPathDelimiter(GetTempDir) + 'lazjson_clipboard_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.json';
  try
    with TStringStream.Create(ClipText) do
    try
      SaveToFile(TempFile);
    finally
      Free;
    end;
    LoadFile(TempFile);
  except
    on E: Exception do
    begin
      // Fallback to AppData if Temp is not writable
      TempFile := IncludeTrailingPathDelimiter(GetAppConfigFolder) + 'lazjson_clipboard_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.json';
      try
        with TStringStream.Create(ClipText) do
        try
          SaveToFile(TempFile);
        finally
          Free;
        end;
        LoadFile(TempFile);
      except
        on E2: Exception do
          MessageDlg('Paste Error', 'Failed to write clipboard data: ' + E2.Message, mtError, [mbOK], 0);
      end;
    end;
  end;
end;

const
  MAX_RECENT_FILES = 10;
  RECENT_FILES_CFG = 'lazjson_recent.txt';

procedure TFrmMain.LoadRecentFiles;
var
  CfgFile: string;
  LegacyCfgFile: string;
  TempCfgFile: string;
  ExecutableCfgFile: string;
  LoadedFromFile: string;
begin
  if FRecentFiles = nil then
    FRecentFiles := TStringList.Create;

  FRecentFiles.Clear;

  CfgFile := IncludeTrailingPathDelimiter(GetAppConfigFolder) + RECENT_FILES_CFG;
  LegacyCfgFile := IncludeTrailingPathDelimiter(GetLegacyAppConfigFolder) + RECENT_FILES_CFG;
  TempCfgFile := IncludeTrailingPathDelimiter(GetTempDir) + RECENT_FILES_CFG;
  ExecutableCfgFile := IncludeTrailingPathDelimiter(ExtractFilePath(Application.ExeName)) + RECENT_FILES_CFG;
  LoadedFromFile := '';

  if TryLoadRecentFilesFromPath(CfgFile, FRecentFiles) then
    LoadedFromFile := CfgFile
  else if (not SameFileName(LegacyCfgFile, CfgFile)) and TryLoadRecentFilesFromPath(LegacyCfgFile, FRecentFiles) then
    LoadedFromFile := LegacyCfgFile
  else if (not SameFileName(ExecutableCfgFile, CfgFile)) and TryLoadRecentFilesFromPath(ExecutableCfgFile, FRecentFiles) then
    LoadedFromFile := ExecutableCfgFile
  else if TryLoadRecentFilesFromPath(TempCfgFile, FRecentFiles) then
    LoadedFromFile := TempCfgFile;

  if (LoadedFromFile <> '') and (not SameFileName(LoadedFromFile, CfgFile)) then
    SaveRecentFiles;

  UpdateRecentFilesMenu;
end;

procedure TFrmMain.SaveRecentFiles;
var
  CfgFile: string;
  FS: TFileStream;
begin
  if FRecentFiles <> nil then
  begin
    CfgFile := IncludeTrailingPathDelimiter(GetAppConfigFolder) + RECENT_FILES_CFG;
    try
      FS := TFileStream.Create(CfgFile, fmCreate or fmShareDenyNone);
      try
        FRecentFiles.SaveToStream(FS);
      finally
        FS.Free;
      end;
    except
      on E: Exception do
      begin
        // Silently ignore or log error
      end;
    end;
  end;
end;

procedure TFrmMain.AddRecentFile(const AFileName: string);
var
  Idx: Integer;
begin
  if FRecentFiles = nil then Exit;
  
  Idx := FRecentFiles.IndexOf(AFileName);
  if Idx >= 0 then
    FRecentFiles.Delete(Idx);
    
  FRecentFiles.Insert(0, AFileName);
  
  while FRecentFiles.Count > MAX_RECENT_FILES do
    FRecentFiles.Delete(FRecentFiles.Count - 1);
    
  SaveRecentFiles;
  UpdateRecentFilesMenu;
end;

procedure TFrmMain.UpdateRecentFilesMenu;
var
  I: Integer;
  MenuItem: TMenuItem;
begin
  mnuRecentFiles.Clear;
  
  if (FRecentFiles = nil) or (FRecentFiles.Count = 0) then
  begin
    MenuItem := TMenuItem.Create(mnuRecentFiles);
    MenuItem.Caption := '(Empty)';
    MenuItem.Enabled := False;
    mnuRecentFiles.Add(MenuItem);
    Exit;
  end;

  for I := 0 to FRecentFiles.Count - 1 do
  begin
    MenuItem := TMenuItem.Create(mnuRecentFiles);
    MenuItem.Caption := IntToStr(I + 1) + '. ' + ExtractFileName(FRecentFiles[I]);
    MenuItem.Hint := FRecentFiles[I]; // Store full path in Hint
    MenuItem.OnClick := @OnRecentFileClick;
    mnuRecentFiles.Add(MenuItem);
  end;
  
  // Add Clear option
  MenuItem := TMenuItem.Create(mnuRecentFiles);
  MenuItem.Caption := '-';
  mnuRecentFiles.Add(MenuItem);
  
  MenuItem := TMenuItem.Create(mnuRecentFiles);
  MenuItem.Caption := 'Clear Recent Files';
  MenuItem.OnClick := @mnuRecentFilesClick;
  mnuRecentFiles.Add(MenuItem);
end;

procedure TFrmMain.OnRecentFileClick(Sender: TObject);
var
  MenuItem: TMenuItem;
  FilePath: string;
begin
  if Sender is TMenuItem then
  begin
    MenuItem := TMenuItem(Sender);
    FilePath := MenuItem.Hint;
    if FileExists(FilePath) then
      LoadFile(FilePath)
    else
    begin
      MessageDlg('File Not Found', 'The file could not be found: ' + LineEnding + FilePath, mtError, [mbOK], 0);
      FRecentFiles.Delete(FRecentFiles.IndexOf(FilePath));
      SaveRecentFiles;
      UpdateRecentFilesMenu;
    end;
  end;
end;

procedure TFrmMain.mnuRecentFilesClick(Sender: TObject);
begin
  if FRecentFiles <> nil then
  begin
    FRecentFiles.Clear;
    SaveRecentFiles;
    UpdateRecentFilesMenu;
  end;
end;

procedure TFrmMain.mnuExportAsClick(Sender: TObject);
var
  SaveDlg: TSaveDialog;
  Src, Dest: TFileStream;
  Format: TExportFormat;
  Entry: TJSONIndexEntry;
  RawJSON: string;
  Bytes: TBytes;
begin
  if not FFileHandler.IsOpen then Exit;

  Format := efJSON;
  if Sender is TMenuItem then
    Format := TExportFormat((Sender as TMenuItem).Tag);

  // If simple JSON export, we can just copy the file, no need to parse
  if Format = efJSON then
  begin
    SaveDlg := TSaveDialog.Create(Self);
    try
      SaveDlg.Options := SaveDlg.Options + [ofNoTestFileCreate, ofOverwritePrompt];
      SaveDlg.Filter := TDataExporter.GetFilter(Format);
      SaveDlg.DefaultExt := TDataExporter.GetDefaultExtension(Format);
      SaveDlg.FileName := ExtractFileName(FCurrentFileName);
      if SaveDlg.Execute then
      begin
        try
          Src := TFileStream.Create(FCurrentFileName, fmOpenRead or fmShareDenyNone);
          try
            Dest := TFileStream.Create(SaveDlg.FileName, fmCreate);
            try
              Dest.CopyFrom(Src, Src.Size);
            finally
              Dest.Free;
            end;
          finally
            Src.Free;
          end;
        except
          on E: Exception do
            MessageDlg('Error', 'Failed to save file: ' + E.Message, mtError, [mbOK], 0);
        end;
      end;
    finally
      SaveDlg.Free;
    end;
    Exit;
  end;

  // Other formats: Need to read whole file into string
  if FIndex.Count = 0 then Exit;
  Entry := FIndex[FIndex.RootIndex];

  if Entry.FileLength > 50 * 1024 * 1024 then
  begin
    if MessageDlg('Large File Warning', 'Converting a file larger than 50MB may consume significant memory and take a long time. Do you want to proceed?', mtWarning, [mbYes, mbNo], 0) <> mrYes then
      Exit;
  end;

  Bytes := FFileHandler.ReadBytes(Entry.FileOffset, Entry.FileLength);
  SetString(RawJSON, PAnsiChar(@Bytes[0]), Length(Bytes));
  ExportToFile(RawJSON, Format);
end;

procedure TFrmMain.mnuExportSectionAsClick(Sender: TObject);
var
  Data: TJSONNodeData;
  Format: TExportFormat;
begin
  if FVirtualTree.SelectedNodeIndex < 0 then Exit;
  Data := FVirtualTree.GetSelectedNodeData;

  Format := efJSON;
  if Sender is TMenuItem then
    Format := TExportFormat((Sender as TMenuItem).Tag);

  ExportToFile(Data.FullValue, Format);
end;

procedure TFrmMain.mnuExportSectionAsJSONClick(Sender: TObject);
begin
  mnuExportSectionAsClick(Sender);
end;

procedure TFrmMain.mnuQuitClick(Sender: TObject);
begin
  Close;
end;

{ ══════════════════════════════════════════════════════════════════════
  MENU EVENT HANDLERS — Edit
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.mnuEditClick(Sender: TObject);
var
  HasSelection: Boolean;
begin
  HasSelection := FVirtualTree.SelectedNodeIndex >= 0;
  mnuCopyData.Enabled := FCurrentFileName <> '';
  mnuCopyDataAs.Enabled := FCurrentFileName <> '';
  mnuCopySelectionName.Enabled := HasSelection;
  mnuCopySelectionValue.Enabled := HasSelection;
  mnuCopySelectionValueAs.Enabled := HasSelection;
  mnuCopySelectionPath.Enabled := HasSelection;
end;

procedure TFrmMain.mnuFindClick(Sender: TObject);
begin
  edtSearch.SetFocus;
  edtSearch.SelectAll;
end;

procedure TFrmMain.mnuFindNextClick(Sender: TObject);
var
  NodeIdx: Integer;
begin
  NodeIdx := FSearchEngine.NextResult;
  if NodeIdx >= 0 then
    NavigateToSearchResult(NodeIdx);
end;

procedure TFrmMain.mnuFindPreviousClick(Sender: TObject);
var
  NodeIdx: Integer;
begin
  NodeIdx := FSearchEngine.PreviousResult;
  if NodeIdx >= 0 then
    NavigateToSearchResult(NodeIdx);
end;

procedure TFrmMain.mnuCopyDataClick(Sender: TObject);
var
  Entry: TJSONIndexEntry;
  RawJSON: string;
  Bytes: TBytes;
begin
  if not FFileHandler.IsOpen then Exit;
  if FIndex.Count = 0 then Exit;

  Entry := FIndex[FIndex.RootIndex];

  if Entry.FileLength > 50 * 1024 * 1024 then
  begin
    MessageDlg('Copy Failed', 'The document is too large to copy to the clipboard (> 50 MB). Please use "Export As" instead.', mtWarning, [mbOK], 0);
    Exit;
  end;

  Bytes := FFileHandler.ReadBytes(Entry.FileOffset, Entry.FileLength);
  SetString(RawJSON, PAnsiChar(@Bytes[0]), Length(Bytes));
  Clipboard.AsText := RawJSON;

  FStatusManager.SetNodePath('Data copied to clipboard');
end;

procedure TFrmMain.mnuMinifiedJsonClick(Sender: TObject);
begin
  { Copy entire data as minified JSON }
  mnuCopyDataClick(Sender); // For now, same as raw copy
end;

procedure TFrmMain.mnuBeautifiedJsonClick(Sender: TObject);
var
  Entry: TJSONIndexEntry;
  RawJSON: string;
  Bytes: TBytes;
begin
  if not FFileHandler.IsOpen then Exit;
  if FIndex.Count = 0 then Exit;

  Entry := FIndex[FIndex.RootIndex];

  if Entry.FileLength > 50 * 1024 * 1024 then
  begin
    MessageDlg('Copy Failed', 'The document is too large to copy to the clipboard (> 50 MB). Please use "Export As" instead.', mtWarning, [mbOK], 0);
    Exit;
  end;

  Bytes := FFileHandler.ReadBytes(Entry.FileOffset, Entry.FileLength);
  SetString(RawJSON, PAnsiChar(@Bytes[0]), Length(Bytes));
  Clipboard.AsText := BeautifyJSONString(RawJSON);

  FStatusManager.SetNodePath('Beautified data copied to clipboard');
end;

procedure TFrmMain.mnuCopySelectionNameClick(Sender: TObject);
begin
  FVirtualTree.CopySelectedName;
  FStatusManager.SetNodePath('Name copied to clipboard');
end;

procedure TFrmMain.mnuCopySelectionValueClick(Sender: TObject);
begin
  FVirtualTree.CopySelectedValue;
  FStatusManager.SetNodePath('Value copied to clipboard');
end;

procedure TFrmMain.mnuMinifiedValueClick(Sender: TObject);
begin
  FVirtualTree.CopySelectedSubtreeAsJSON(False);
  FStatusManager.SetNodePath('Minified value copied to clipboard');
end;

procedure TFrmMain.mnuBeautifiedValueClick(Sender: TObject);
begin
  FVirtualTree.CopySelectedSubtreeAsJSON(True);
  FStatusManager.SetNodePath('Beautified value copied to clipboard');
end;

procedure TFrmMain.mnuCopySelectionPathClick(Sender: TObject);
begin
  FVirtualTree.CopySelectedPath;
  FStatusManager.SetNodePath('Path copied to clipboard');
end;

procedure TFrmMain.mnuPreferencesClick(Sender: TObject);
var
  PreferencesDialog: TPreferencesDialog;
begin
  PreferencesDialog := TPreferencesDialog.CreateDialog(Self, Self);
  try
    PreferencesDialog.SetAutoRefreshMode(FAutoRefreshMode);
    PreferencesDialog.SetAlwaysOnTop(FAlwaysOnTop);
    if PreferencesDialog.ShowModal = mrOk then
    begin
      FAutoRefreshMode := PreferencesDialog.GetAutoRefreshMode;
      FAlwaysOnTop := PreferencesDialog.GetAlwaysOnTop;
      FSessionAlwaysOnTop := FAlwaysOnTop;
      ApplyAlwaysOnTop;
      SavePreferences;
      HandleDetectedFileChange(False);
    end;
  finally
    PreferencesDialog.Free;
  end;
end;

procedure TFrmMain.popCopyNameClick(Sender: TObject);
begin
  mnuCopySelectionNameClick(Sender);
end;

procedure TFrmMain.popCopyValueClick(Sender: TObject);
begin
  mnuCopySelectionValueClick(Sender);
end;

procedure TFrmMain.popCopyMinifiedValueClick(Sender: TObject);
begin
  mnuMinifiedValueClick(Sender);
end;

procedure TFrmMain.popCopyFormattedValueClick(Sender: TObject);
begin
  mnuBeautifiedValueClick(Sender);
end;

procedure TFrmMain.popCopyPathClick(Sender: TObject);
begin
  mnuCopySelectionPathClick(Sender);
end;

procedure TFrmMain.popExportJSONClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    (Sender as TMenuItem).Tag := Ord(efJSON);
  mnuExportSectionAsClick(Sender);
end;

procedure TFrmMain.popExportMinifiedJSONClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    (Sender as TMenuItem).Tag := Ord(efMinifiedJSON);
  mnuExportSectionAsClick(Sender);
end;

procedure TFrmMain.popExportFormattedJSONClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    (Sender as TMenuItem).Tag := Ord(efBeautifiedJSON);
  mnuExportSectionAsClick(Sender);
end;

procedure TFrmMain.popExportMinifiedXMLClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    (Sender as TMenuItem).Tag := Ord(efMinifiedXML);
  mnuExportSectionAsClick(Sender);
end;

procedure TFrmMain.popExportFormattedXMLClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    (Sender as TMenuItem).Tag := Ord(efBeautifiedXML);
  mnuExportSectionAsClick(Sender);
end;

procedure TFrmMain.popExportCSVClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    (Sender as TMenuItem).Tag := Ord(efCSV);
  mnuExportSectionAsClick(Sender);
end;

procedure TFrmMain.popExportYAMLClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    (Sender as TMenuItem).Tag := Ord(efYAML);
  mnuExportSectionAsClick(Sender);
end;

procedure TFrmMain.popExportTOMLClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    (Sender as TMenuItem).Tag := Ord(efTOML);
  mnuExportSectionAsClick(Sender);
end;

{ ══════════════════════════════════════════════════════════════════════
  MENU EVENT HANDLERS — View
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.mnuHideStatusBarClick(Sender: TObject);
begin
  StatusBar2.Visible := not StatusBar2.Visible;
  if StatusBar2.Visible then
    mnuHideStatusBar.Caption := 'Hide Status Bar'
  else
    mnuHideStatusBar.Caption := 'Show Status Bar';
end;

procedure TFrmMain.mnuHideNodePathClick(Sender: TObject);
begin
  StatusBar1.Visible := not StatusBar1.Visible;
  if StatusBar1.Visible then
    mnuHideNodePath.Caption := 'Hide Node Path'
  else
    mnuHideNodePath.Caption := 'Show Node Path';
end;

procedure TFrmMain.mnuRefreshClick(Sender: TObject);
begin
  if (FCurrentFileName <> '') and ConfirmLargeFileRefresh then
    LoadFile(FCurrentFileName);
end;

procedure TFrmMain.mnuCollapseAllNodeClick(Sender: TObject);
begin
  FVirtualTree.CollapseAll;
end;

procedure TFrmMain.mnuCollapseCurrentLevelClick(Sender: TObject);
begin
  FVirtualTree.CollapseCurrentLevel;
end;

{ ══════════════════════════════════════════════════════════════════════
  MENU EVENT HANDLERS — Help
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.mnuAboutClick(Sender: TObject);
begin
  MessageDlg('About ' + APP_TITLE,
    APP_TITLE + ' v' + APP_VERSION + #13#10 +
    #13#10 +
    'A high-performance JSON viewer for large files.' + #13#10 +
    'Built with Lazarus/Free Pascal.' + #13#10 +
    #13#10 +
    'Features:' + #13#10 +
    '  • Memory-mapped file I/O' + #13#10 +
    '  • Streaming parser with explicit stack' + #13#10 +
    '  • On-demand node materialization' + #13#10 +
    '  • LRU cache for visited nodes' + #13#10 +
    '  • Syntax-highlighted tree view' + #13#10 +
    '  • Full-text search across keys and values',
    mtInformation, [mbOK], 0);
end;

procedure TFrmMain.mnuReleaseNotesClick(Sender: TObject);
begin
  MessageDlg('Release Notes',
    'Version ' + APP_VERSION + #13#10 +
    '• Initial release' + #13#10 +
    '• Core JSON parsing engine' + #13#10 +
    '• Memory-mapped file support' + #13#10 +
    '• Virtual tree view with lazy loading' + #13#10 +
    '• Search with case-sensitivity toggle',
    mtInformation, [mbOK], 0);
end;

{ ══════════════════════════════════════════════════════════════════════
  SEARCH BAR EVENT HANDLERS
  ══════════════════════════════════════════════════════════════════════ }

procedure TFrmMain.edtSearchChange(Sender: TObject);
begin
  { Debounce: restart timer on each keystroke }
  FSearchDebounceTimer.Enabled := False;
  FSearchDebounceTimer.Enabled := True;
end;

procedure TFrmMain.btnCaseClick(Sender: TObject);
begin
  FCaseSensitive := btnCase.Down;
  if edtSearch.Text <> '' then
    ExecuteSearch;
end;

procedure TFrmMain.Action1Execute(Sender: TObject);
begin

end;

procedure TFrmMain.btnPreviousClick(Sender: TObject);
var
  NodeIdx: Integer;
begin
  NodeIdx := FSearchEngine.PreviousResult;
  if NodeIdx >= 0 then
    NavigateToSearchResult(NodeIdx);
end;

procedure TFrmMain.btnNextClick(Sender: TObject);
var
  NodeIdx: Integer;
begin
  NodeIdx := FSearchEngine.NextResult;
  if NodeIdx >= 0 then
    NavigateToSearchResult(NodeIdx);
end;

procedure TFrmMain.btnRegExClick(Sender: TObject);
begin
  FUseRegEx := btnRegEx.Down;
  if edtSearch.Text <> '' then
    ExecuteSearch;
end;

procedure TFrmMain.HandleDropFiles(Sender: TObject; const FileNames: array of string);
begin
  if Length(FileNames) > 0 then
    LoadFile(FileNames[0]);
end;

end.
