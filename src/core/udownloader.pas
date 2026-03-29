unit uDownloader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, base64
  {$IFDEF WINDOWS}
  , Windows, winhttp
  {$ELSE}
  , fphttpclient, opensslsockets
  {$ENDIF};

type
  TDownloadProgressEvent = procedure(const Msg: string; Percent: Integer) of object;
  TDownloadCompleteEvent = procedure(const TempFile: string) of object;
  TDownloadErrorEvent = procedure(const ErrorMsg: string) of object;

const
  ENABLE_DOWNLOADER_TRACE = False;

type
  { TDownloadThread }

  TDownloadThread = class(TThread)
  private
    FURL: string;
    FTempFile: string;
    FAuthType: Integer; // 0 = None, 1 = Basic, 2 = Bearer
    FToken: string;
    FUsername: string;
    FPassword: string;
    FErrorMsg: string;
    FSuccess: Boolean;
    FTotalRead: Int64;
    FContentLength: Int64;
    FProgressPercent: Integer;
    FLastTick: QWord;
    FDebugLog: TStringList;

    FOnProgress: TDownloadProgressEvent;
    FOnComplete: TDownloadCompleteEvent;
    FOnError: TDownloadErrorEvent;

    procedure DebugLog(const Msg: string);
    procedure UpdateUI;
    procedure DownloadComplete;
    procedure DownloadError;
  protected
    procedure Execute; override;
  public
    constructor Create(const AURL, ATempFile: string; AAuthType: Integer = 0;
      const AToken: string = ''; const AUser: string = ''; const APass: string = '');
    destructor Destroy; override;
    property OnProgress: TDownloadProgressEvent read FOnProgress write FOnProgress;
    property OnComplete: TDownloadCompleteEvent read FOnComplete write FOnComplete;
    property OnError: TDownloadErrorEvent read FOnError write FOnError;
  end;

implementation

{ TDownloadThread }

constructor TDownloadThread.Create(const AURL, ATempFile: string; AAuthType: Integer;
  const AToken: string; const AUser: string; const APass: string);
begin
  inherited Create(True); // Create suspended
  FreeOnTerminate := True;
  FURL := AURL;
  FTempFile := ATempFile;
  FAuthType := AAuthType;
  FToken := AToken;
  FUsername := AUser;
  FPassword := APass;
  FSuccess := False;
  FErrorMsg := '';
  FTotalRead := 0;
  FContentLength := 0;
  FProgressPercent := 0;
  if ENABLE_DOWNLOADER_TRACE then
  begin
    FDebugLog := TStringList.Create;
    DebugLog('TDownloadThread.Create - URL: ' + AURL);
    DebugLog('  AuthType: ' + IntToStr(AAuthType) + ', TempFile: ' + ATempFile);
  end
  else
    FDebugLog := nil;
end;

destructor TDownloadThread.Destroy;
var
  LogFile: string;
begin
  DebugLog('TDownloadThread.Destroy - Success: ' + BoolToStr(FSuccess, True));
  DebugLog('  TotalRead: ' + IntToStr(FTotalRead) + ', ContentLength: ' + IntToStr(FContentLength));
  if FErrorMsg <> '' then
    DebugLog('  Error: ' + FErrorMsg);

  if ENABLE_DOWNLOADER_TRACE and Assigned(FDebugLog) and (not FSuccess or (FErrorMsg <> '')) then
  begin
    LogFile := ChangeFileExt(FTempFile, '.log');
    FDebugLog.SaveToFile(LogFile);
    DebugLog('  Log saved to: ' + LogFile);
  end;

  if Assigned(FDebugLog) then
    FDebugLog.Free;
  inherited Destroy;
end;

procedure TDownloadThread.DebugLog(const Msg: string);
var
  TimeStr: string;
begin
  if not Assigned(FDebugLog) then Exit;
  TimeStr := FormatDateTime('hh:nn:ss.zzz', Now);
  FDebugLog.Add('[' + TimeStr + '] ' + Msg);

  {$IFDEF WINDOWS}
  OutputDebugString(PChar('[Downloader] ' + Msg));
  {$ENDIF}
end;

procedure TDownloadThread.UpdateUI;
begin
  if Assigned(FOnProgress) then
  begin
    if FContentLength > 0 then
      FOnProgress(Format('Downloading JSON... (%.1f MB)', [FTotalRead / 1048576]), FProgressPercent)
    else if FTotalRead > 0 then
      FOnProgress(Format('Downloading JSON... (%.1f MB)', [FTotalRead / 1048576]), 0)
    else
      FOnProgress('Downloading JSON...', 0);
  end;
end;

procedure TDownloadThread.DownloadComplete;
begin
  if FSuccess and Assigned(FOnComplete) then
    FOnComplete(FTempFile)
  else if not FSuccess and Assigned(FOnError) then
    FOnError('Failed to download JSON from URL.' + LineEnding + 'Please check the URL and your internet connection.');
end;

procedure TDownloadThread.DownloadError;
begin
  if Assigned(FOnError) then
    FOnError(FErrorMsg);
  if FileExists(FTempFile) then SysUtils.DeleteFile(FTempFile);
end;

procedure TDownloadThread.Execute;
{$IFDEF WINDOWS}
var
  hSession, hConnect, hRequest: HINTERNET;
  Buffer: array[0..32767] of Byte;
  BytesRead: DWORD;
  F: TFileStream;
  URLComp: URL_COMPONENTS;
  HostName, UrlPath: WideString;
  Headers: WideString;
  dwSize, dwIndex: DWORD;
  LenBuffer: array[0..63] of WideChar;
  IsHttps: Boolean;
  RequestFlags: DWORD;
  LastError: DWORD;
  ReadFailed: Boolean;
{$ELSE}
var
  Client: TFPHTTPClient;
{$ENDIF}
begin
  try
    {$IFDEF WINDOWS}
    DebugLog('Execute: Starting download - URL: ' + FURL);
    Synchronize(@UpdateUI);

    DebugLog('Execute: Parsing URL...');
    FillChar(URLComp, SizeOf(URLComp), 0);
    URLComp.dwStructSize := SizeOf(URLComp);

    SetLength(HostName, Length(FURL));
    URLComp.lpszHostName := PWideChar(HostName);
    URLComp.dwHostNameLength := Length(HostName);

    SetLength(UrlPath, Length(FURL));
    URLComp.lpszUrlPath := PWideChar(UrlPath);
    URLComp.dwUrlPathLength := Length(UrlPath);

    if not WinHttpCrackUrl(PWideChar(WideString(FURL)), 0, 0, @URLComp) then
    begin
      LastError := GetLastError;
      raise Exception.Create('Invalid URL format. LastError: ' + IntToStr(LastError));
    end;

    IsHttps := URLComp.nScheme = INTERNET_SCHEME_HTTPS;
    DebugLog('Execute: URL parsed - Scheme: ' + IntToStr(URLComp.nScheme) + ', Host: ' + HostName + ', Port: ' + IntToStr(URLComp.nPort) + ', IsHttps: ' + BoolToStr(IsHttps, True));

    SetLength(HostName, URLComp.dwHostNameLength);
    SetLength(UrlPath, URLComp.dwUrlPathLength);
    if UrlPath = '' then UrlPath := '/';
    DebugLog('Execute: Opening WinHTTP session...');

    hSession := WinHttpOpen('LargeJSONViewer', WINHTTP_ACCESS_TYPE_DEFAULT_PROXY,
                           WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if not Assigned(hSession) then
    begin
      LastError := GetLastError;
      raise Exception.Create('Could not initialize WinHTTP session. LastError: ' + IntToStr(LastError));
    end;
    DebugLog('Execute: WinHTTP session opened.');

    try
      DebugLog('Execute: Connecting to server...');
      hConnect := WinHttpConnect(hSession, PWideChar(HostName), URLComp.nPort, 0);
      if not Assigned(hConnect) then
      begin
        LastError := GetLastError;
        raise Exception.Create('Could not connect to server. LastError: ' + IntToStr(LastError));
      end;
      DebugLog('Execute: Connected to server.');

      try
        RequestFlags := 0;
        if IsHttps then
        begin
          RequestFlags := WINHTTP_FLAG_SECURE;
          DebugLog('Execute: HTTPS detected, adding SECURE flag.');
        end;

        DebugLog('Execute: Opening request...');
        hRequest := WinHttpOpenRequest(hConnect, 'GET', PWideChar(UrlPath), nil,
                                      WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
                                      RequestFlags);
        if not Assigned(hRequest) then
        begin
          LastError := GetLastError;
          raise Exception.Create('Could not create HTTP request. LastError: ' + IntToStr(LastError));
        end;
        DebugLog('Execute: Request opened.');

        try
          Headers := '';
          if FAuthType = 1 then // Basic
          begin
            Headers := 'Authorization: Basic ' + WideString(EncodeStringBase64(FUsername + ':' + FPassword)) + #13#10;
            DebugLog('Execute: Using Basic authentication.');
          end
          else if FAuthType = 2 then // Bearer
          begin
            Headers := 'Authorization: Bearer ' + WideString(FToken) + #13#10;
            DebugLog('Execute: Using Bearer authentication.');
          end
          else
            DebugLog('Execute: No authentication.');

          DebugLog('Execute: Sending request...');
          if not WinHttpSendRequest(hRequest,
            PWideChar(Headers),
            Length(Headers),
            WINHTTP_NO_REQUEST_DATA, 0, 0, 0) then
          begin
            LastError := GetLastError;
            raise Exception.Create('Failed to send HTTP request. LastError: ' + IntToStr(LastError));
          end;
          DebugLog('Execute: Request sent.');

          DebugLog('Execute: Receiving response...');
          if not WinHttpReceiveResponse(hRequest, nil) then
          begin
            LastError := GetLastError;
            raise Exception.Create('Failed to receive HTTP response. LastError: ' + IntToStr(LastError));
          end;
          DebugLog('Execute: Response received.');
            
          // Get Content Length if available
          FContentLength := 0;
          dwSize := SizeOf(LenBuffer);
          dwIndex := 0;
          DebugLog('Execute: Querying Content-Length header...');
          if WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_CONTENT_LENGTH,
                                WINHTTP_HEADER_NAME_BY_INDEX, @LenBuffer, @dwSize, @dwIndex) then
          begin
            FContentLength := StrToInt64Def(string(PWideChar(@LenBuffer)), 0);
            DebugLog('Execute: Content-Length: ' + IntToStr(FContentLength));
          end
          else
          begin
            DebugLog('Execute: Content-Length header not found.');
          end;

          DebugLog('Execute: Starting download to file: ' + FTempFile);
          F := TFileStream.Create(FTempFile, fmCreate or fmShareDenyNone);
          try
            FTotalRead := 0;
            ReadFailed := False;
            FLastTick := GetTickCount64;
            Synchronize(@UpdateUI);
            
            repeat
              if Terminated then
              begin
                DebugLog('Execute: Download terminated by user.');
                Break;
              end;

              if WinHttpReadData(hRequest, @Buffer, SizeOf(Buffer), @BytesRead) then
              begin
                if BytesRead > 0 then
                begin
                  F.WriteBuffer(Buffer, BytesRead);
                  Inc(FTotalRead, BytesRead);

                  if FContentLength > 0 then
                    FProgressPercent := (FTotalRead * 100) div FContentLength
                  else
                    FProgressPercent := 0;

                  if GetTickCount64 - FLastTick > 50 then
                  begin
                    Synchronize(@UpdateUI);
                    FLastTick := GetTickCount64;
                  end;
                end
                else
                begin
                  DebugLog('Execute: Read 0 bytes - download complete.');
                end;
              end
              else
              begin
                LastError := GetLastError;
                DebugLog('Execute: WinHttpReadData failed. LastError: ' + IntToStr(LastError));
                ReadFailed := True;
                raise Exception.Create('Failed while reading HTTP response. LastError: ' + IntToStr(LastError));
              end;
            until BytesRead = 0;

            if (not Terminated) and (not ReadFailed) then
            begin
              DebugLog('Execute: Download completed successfully. TotalRead: ' + IntToStr(FTotalRead));
              FSuccess := True;
            end;
          finally
            F.Free;
          end;
        finally
          WinHttpCloseHandle(hRequest);
        end;
      finally
        WinHttpCloseHandle(hConnect);
      end;
    finally
      WinHttpCloseHandle(hSession);
    end;
    
    {$ELSE}
    DebugLog('Execute [Linux]: Starting download - URL: ' + FURL);
    Client := TFPHTTPClient.Create(nil);
    try
      DebugLog('Execute [Linux]: Configuring client...');
      Client.AllowRedirect := True;
      if FAuthType = 1 then
      begin
        Client.AddHeader('Authorization', 'Basic ' + string(EncodeStringBase64(FUsername + ':' + FPassword)));
        DebugLog('Execute [Linux]: Using Basic authentication.');
      end
      else if FAuthType = 2 then
      begin
        Client.AddHeader('Authorization', 'Bearer ' + FToken);
        DebugLog('Execute [Linux]: Using Bearer authentication.');
      end
      else
        DebugLog('Execute [Linux]: No authentication.');

      DebugLog('Execute [Linux]: Starting GET request...');
      Client.Get(FURL, FTempFile);
      DebugLog('Execute [Linux]: Request completed.');

      if not Terminated then
      begin
        DebugLog('Execute [Linux]: Download completed successfully.');
        FSuccess := True;
      end;
    finally
      Client.Free;
    end;
    {$ENDIF}

    if not Terminated and FSuccess then
      Synchronize(@DownloadComplete);

  except
    on E: Exception do
    begin
      DebugLog('Execute: Exception caught - ' + E.ClassName + ': ' + E.Message);
      FErrorMsg := E.Message;
      if not Terminated then
        Synchronize(@DownloadError);
    end;
  end;
end;

end.
