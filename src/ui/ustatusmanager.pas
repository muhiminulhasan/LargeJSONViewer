unit uStatusManager;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ComCtrls, uJsonTypes;

type
  { ── TStatusManager ───────────────────────────────────────────────
    Manages the two status bars at the bottom of the main form:
    - StatusBar1 (top): Node path display ($.data[0].name)
    - StatusBar2 (bottom): File info, node count, memory, timing
  ─────────────────────────────────────────────────────────────────── }

  TStatusManager = class
  private
    FPathBar: TStatusBar;
    FInfoBar: TStatusBar;

    FFileName: string;
    FFileSize: Int64;
    FNodeCount: Integer;
    FLoadTimeMs: Int64;
    FMemoryUsed: Int64;
    FSearchInfo: string;

    procedure SetupPanels;
    procedure UpdateInfoBar;
  public
    constructor Create(APathBar, AInfoBar: TStatusBar);

    { Update the node path display }
    procedure SetNodePath(const APath: string);

    { Update file information }
    procedure SetFileInfo(const AFileName: string; AFileSize: Int64;
      ANodeCount: Integer; ALoadTimeMs: Int64);

    { Update memory usage display }
    procedure SetMemoryUsage(ABytes: Int64);

    { Update search status }
    procedure SetSearchInfo(const AInfo: string);

    { Show loading progress }
    procedure SetProgress(const AMessage: string; APercentage: Double);

    { Show ready state }
    procedure SetReady;

    { Clear all status }
    procedure Clear;

    { Toggle path bar visibility }
    procedure SetPathBarVisible(AVisible: Boolean);

    { Toggle info bar visibility }
    procedure SetInfoBarVisible(AVisible: Boolean);
  end;

implementation

{ ── TStatusManager ───────────────────────────────────────────────── }

constructor TStatusManager.Create(APathBar, AInfoBar: TStatusBar);
begin
  inherited Create;
  FPathBar := APathBar;
  FInfoBar := AInfoBar;
  FFileName := '';
  FFileSize := 0;
  FNodeCount := 0;
  FLoadTimeMs := 0;
  FMemoryUsed := 0;
  FSearchInfo := '';

  SetupPanels;
end;

procedure TStatusManager.SetupPanels;
begin
  { Path bar — single panel stretching full width }
  FPathBar.SimplePanel := True;
  FPathBar.SimpleText := 'Ready — Open a JSON file to begin';

  { Info bar — multiple panels }
  FInfoBar.SimplePanel := False;
  FInfoBar.Panels.Clear;

  { Panel 0: File Name }
  with FInfoBar.Panels.Add do
  begin
    Width := 250;
    Text := 'No file loaded';
  end;

  { Panel 1: File Size }
  with FInfoBar.Panels.Add do
  begin
    Width := 150;
    Text := 'Size: 0 bytes';
  end;

  { Panel 2: Node Count }
  with FInfoBar.Panels.Add do
  begin
    Width := 150;
    Text := 'Count: 0';
  end;

  { Panel 3: Load Time }
  with FInfoBar.Panels.Add do
  begin
    Width := 150;
    Text := 'Load: 0ms';
  end;

  { Panel 4: Memory }
  with FInfoBar.Panels.Add do
  begin
    Width := 150;
    Text := 'Memory: 0 MB';
  end;

  { Panel 5: Search/Extras }
  with FInfoBar.Panels.Add do
  begin
    Width := 200;
    Text := '';
  end;
end;

procedure TStatusManager.SetNodePath(const APath: string);
begin
  FPathBar.SimpleText := 'Path: ' + APath;
end;

procedure TStatusManager.SetFileInfo(const AFileName: string; AFileSize: Int64;
  ANodeCount: Integer; ALoadTimeMs: Int64);
begin
  FFileName := ExtractFileName(AFileName);
  FFileSize := AFileSize;
  FNodeCount := ANodeCount;
  FLoadTimeMs := ALoadTimeMs;
  UpdateInfoBar;
end;

procedure TStatusManager.SetMemoryUsage(ABytes: Int64);
begin
  FMemoryUsed := ABytes;
  if FInfoBar.Panels.Count > 4 then
    FInfoBar.Panels[4].Text := 'Memory: ' + FormatByteSize(ABytes);
end;

procedure TStatusManager.SetSearchInfo(const AInfo: string);
begin
  FSearchInfo := AInfo;
  if FInfoBar.Panels.Count > 5 then
    FInfoBar.Panels[5].Text := AInfo;
end;

procedure TStatusManager.UpdateInfoBar;
begin
  if FInfoBar.Panels.Count >= 4 then
  begin
    if FFileName <> '' then
    begin
      FInfoBar.Panels[0].Text := FFileName;
      FInfoBar.Panels[1].Text := 'Size: ' + FormatByteSize(FFileSize);
      FInfoBar.Panels[2].Text := Format('Count: %s', [FormatFloat('#,##0', FNodeCount)]);
      FInfoBar.Panels[3].Text := Format('Load: %dms', [FLoadTimeMs]);
    end
    else
    begin
      FInfoBar.Panels[0].Text := 'No file loaded';
      FInfoBar.Panels[1].Text := 'Size: 0 bytes';
      FInfoBar.Panels[2].Text := 'Count: 0';
      FInfoBar.Panels[3].Text := 'Load: 0ms';
    end;
  end;
end;

procedure TStatusManager.SetProgress(const AMessage: string; APercentage: Double);
begin
  FPathBar.SimpleText := Format('%s (%.1f%%)', [AMessage, APercentage]);
end;

procedure TStatusManager.SetReady;
begin
  if FFileName <> '' then
    FPathBar.SimpleText := 'Ready — Select a node to view details'
  else
    FPathBar.SimpleText := 'Ready — Open a JSON file to begin';
end;

procedure TStatusManager.Clear;
begin
  FFileName := '';
  FFileSize := 0;
  FNodeCount := 0;
  FLoadTimeMs := 0;
  FMemoryUsed := 0;
  FSearchInfo := '';

  FPathBar.SimpleText := 'Ready — Open a JSON file to begin';
  SetupPanels;
end;

procedure TStatusManager.SetPathBarVisible(AVisible: Boolean);
begin
  FPathBar.Visible := AVisible;
end;

procedure TStatusManager.SetInfoBarVisible(AVisible: Boolean);
begin
  FInfoBar.Visible := AVisible;
end;

end.
