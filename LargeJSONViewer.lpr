program LargeJSONViewer;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  {$IFDEF HASAMIGA}
  athreads,
  {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  SysUtils,
  Forms, uFrmMain, VirtualTrees,
  { Core }
  uJsonTypes, uJsonIndex, uFileHandler, uJsonParser,
  { Search }
  uSearchEngine, uJsonPath,
  { UI }
  uVirtualJsonTree, uStatusManager,
  { Utils }
  uCache, uStringPool,
  uDownloader, ufrmopenurl, uDataExporter;

{$R *.res}
{$R association_icon.res}

begin
  RequireDerivedFormResource:=True;
  Application.Scaled:=True;
  {$PUSH}{$WARN 5044 OFF}
  Application.MainFormOnTaskbar:=True;
  {$POP}
  Application.Initialize;
  Application.CreateForm(TFrmMain, FrmMain);
  if (FrmMain <> nil) and (ParamCount > 0) then
    FrmMain.QueueStartupFile(ParamStr(1));
  Application.Run;
end.
