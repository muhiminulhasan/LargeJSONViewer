unit ufrmopenurl;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons;

type

  { TFrmOpenURL }

  TFrmOpenURL = class(TForm)
    btnCancel: TBitBtn;
    btnOpen: TBitBtn;
    cbAuthType: TComboBox;
    chkRemember: TCheckBox;
    edtURL: TEdit;
    edtToken: TEdit;
    edtUsername: TEdit;
    edtPassword: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    lblToken: TLabel;
    lblUsername: TLabel;
    lblPassword: TLabel;
    pnlAuthContainer: TPanel;
    pnlToken: TPanel;
    pnlBasic: TPanel;
    pnlBottom: TPanel;
    procedure cbAuthTypeChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btnOpenClick(Sender: TObject);
  private
    procedure UpdateAuthFields;
    procedure SaveCredentials;
  public
    function GetURL: string;
    function GetAuthType: Integer;
    function GetToken: string;
    function GetUsername: string;
    function GetPassword: string;
    function GetRemember: Boolean;
  end;

var
  FrmOpenURL: TFrmOpenURL;

implementation

uses IniFiles, base64
  {$IFDEF WINDOWS}
  , Windows
  {$ENDIF};

{$R *.lfm}

const
  AUTH_INI_FILE = 'largejson_auth.ini';

{ ── Platform-Independent Crypto Helpers ─────────────────────────────────── }

{$IFDEF WINDOWS}
type
  DATA_BLOB = record
    cbData: DWORD;
    pbData: PByte;
  end;
  PDATA_BLOB = ^DATA_BLOB;

function CryptProtectData(
  pDataIn: PDATA_BLOB;
  szDataDescr: LPCWSTR;
  pOptionalEntropy: PDATA_BLOB;
  pvReserved: PVOID;
  pPromptStruct: PVOID;
  dwFlags: DWORD;
  pDataOut: PDATA_BLOB
): BOOL; stdcall; external 'crypt32.dll' name 'CryptProtectData';

function CryptUnprotectData(
  pDataIn: PDATA_BLOB;
  ppszDataDescr: PLPWSTR;
  pOptionalEntropy: PDATA_BLOB;
  pvReserved: PVOID;
  pPromptStruct: PVOID;
  dwFlags: DWORD;
  pDataOut: PDATA_BLOB
): BOOL; stdcall; external 'crypt32.dll' name 'CryptUnprotectData';

function LocalFree(hMem: HLOCAL): HLOCAL; stdcall; external 'kernel32.dll' name 'LocalFree';
{$ENDIF}

function EncryptString(const S: string): string;
{$IFDEF WINDOWS}
var
  DataIn, DataOut: DATA_BLOB;
{$ENDIF}
begin
  if S = '' then Exit('');
  Result := S; // Fallback
  
  {$IFDEF WINDOWS}
  DataIn.cbData := Length(S);
  DataIn.pbData := PByte(PChar(S));
  
  if CryptProtectData(@DataIn, nil, nil, nil, nil, 0, @DataOut) then
  begin
    try
      SetLength(Result, DataOut.cbData);
      Move(DataOut.pbData^, Result[1], DataOut.cbData);
      Result := EncodeStringBase64(Result);
    finally
      LocalFree(HLOCAL(DataOut.pbData));
    end;
  end;
  {$ELSE}
  // Simple base64 encoding for non-Windows platforms
  Result := EncodeStringBase64(S);
  {$ENDIF}
end;

function DecryptString(const S: string): string;
{$IFDEF WINDOWS}
var
  DataIn, DataOut: DATA_BLOB;
  DecodedStr: string;
{$ENDIF}
begin
  if S = '' then Exit('');
  Result := S; // Fallback
  
  {$IFDEF WINDOWS}
  try
    DecodedStr := DecodeStringBase64(S);
    if DecodedStr = '' then Exit;
    
    DataIn.cbData := Length(DecodedStr);
    DataIn.pbData := PByte(PChar(DecodedStr));
    
    if CryptUnprotectData(@DataIn, nil, nil, nil, nil, 0, @DataOut) then
    begin
      try
        SetString(Result, PChar(DataOut.pbData), DataOut.cbData);
      finally
        LocalFree(HLOCAL(DataOut.pbData));
      end;
    end;
  except
    // Ignore decoding errors
  end;
  {$ELSE}
  try
    Result := DecodeStringBase64(S);
  except
    Result := S;
  end;
  {$ENDIF}
end;

{ TFrmOpenURL }

procedure TFrmOpenURL.FormCreate(Sender: TObject);
var
  Ini: TIniFile;
begin
  cbAuthType.ItemIndex := 0;
  
  // Load saved credentials
  Ini := TIniFile.Create(IncludeTrailingPathDelimiter(GetTempDir) + AUTH_INI_FILE);
  try
    edtURL.Text := Ini.ReadString('Auth', 'LastURL', '');
    cbAuthType.ItemIndex := Ini.ReadInteger('Auth', 'AuthType', 0);

    edtToken.Text := DecryptString(Ini.ReadString('Auth', 'Token', ''));
    edtUsername.Text := DecryptString(Ini.ReadString('Auth', 'Username', ''));
    edtPassword.Text := DecryptString(Ini.ReadString('Auth', 'Password', ''));
    chkRemember.Checked := Ini.ReadBool('Auth', 'Remember', False);
  finally
    Ini.Free;
  end;
  
  UpdateAuthFields;
end;

procedure TFrmOpenURL.cbAuthTypeChange(Sender: TObject);
begin
  UpdateAuthFields;
end;

procedure TFrmOpenURL.btnOpenClick(Sender: TObject);
begin
  if Trim(edtURL.Text) = '' then
  begin
    MessageDlg('Error', 'Please enter a valid URL.', mtError, [mbOK], 0);
    ModalResult := mrNone;
    Exit;
  end;
  
  SaveCredentials;
end;

procedure TFrmOpenURL.UpdateAuthFields;
var
  Gap: Integer;
begin
  pnlToken.Visible := False;
  pnlBasic.Visible := False;
  chkRemember.Visible := cbAuthType.ItemIndex > 0;
  
  case cbAuthType.ItemIndex of
    1: pnlBasic.Visible := True;
    2: pnlToken.Visible := True;
  end;
  
  if pnlBasic.Visible then
    pnlAuthContainer.Height := Scale96ToForm(65)
  else if pnlToken.Visible then
    pnlAuthContainer.Height := Scale96ToForm(35)
  else
    pnlAuthContainer.Height := 0;

  if cbAuthType.ItemIndex = 0 then
    Gap := Scale96ToForm(10)
  else
    Gap := Scale96ToForm(15);
    
  ClientHeight := pnlAuthContainer.Top + pnlAuthContainer.Height + Gap + pnlBottom.Height;
end;

procedure TFrmOpenURL.SaveCredentials;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(IncludeTrailingPathDelimiter(GetTempDir) + AUTH_INI_FILE);
  try
    Ini.WriteString('Auth', 'LastURL', edtURL.Text);
    
    if chkRemember.Checked then
    begin
      Ini.WriteInteger('Auth', 'AuthType', cbAuthType.ItemIndex);
      Ini.WriteBool('Auth', 'Remember', True);
      
      if cbAuthType.ItemIndex = 1 then
      begin
        Ini.WriteString('Auth', 'Username', EncryptString(edtUsername.Text));
        Ini.WriteString('Auth', 'Password', EncryptString(edtPassword.Text));
        Ini.WriteString('Auth', 'Token', '');
      end
      else if cbAuthType.ItemIndex = 2 then
      begin
        Ini.WriteString('Auth', 'Token', EncryptString(edtToken.Text));
        Ini.WriteString('Auth', 'Username', '');
        Ini.WriteString('Auth', 'Password', '');
      end;
    end
    else
    begin
      Ini.WriteInteger('Auth', 'AuthType', 0);
      Ini.WriteBool('Auth', 'Remember', False);
      Ini.WriteString('Auth', 'Token', '');
      Ini.WriteString('Auth', 'Username', '');
      Ini.WriteString('Auth', 'Password', '');
    end;
  finally
    Ini.Free;
  end;
end;

function TFrmOpenURL.GetURL: string;
begin
  Result := Trim(edtURL.Text);
end;

function TFrmOpenURL.GetAuthType: Integer;
begin
  Result := cbAuthType.ItemIndex;
end;

function TFrmOpenURL.GetToken: string;
begin
  Result := Trim(edtToken.Text);
end;

function TFrmOpenURL.GetUsername: string;
begin
  Result := Trim(edtUsername.Text);
end;

function TFrmOpenURL.GetPassword: string;
begin
  Result := Trim(edtPassword.Text);
end;

function TFrmOpenURL.GetRemember: Boolean;
begin
  Result := chkRemember.Checked;
end;

end.