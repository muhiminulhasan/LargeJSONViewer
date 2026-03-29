unit uDataExporter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, uVirtualJsonTree;

type
  TExportFormat = (efJSON, efMinifiedJSON, efBeautifiedJSON, efMinifiedXML, efBeautifiedXML, efCSV, efYAML, efTOML);

  TDataExporter = class
  private
    class function JSONToXML(AData: TJSONData; const ARootName: string; ABeautify: Boolean; ADepth: Integer = 0): string;
    class function JSONToYAML(AData: TJSONData; ADepth: Integer = 0): string;
    class function JSONToTOML(AData: TJSONData; const APrefix: string = ''): string;
    class procedure ExtractCSVHeaders(AData: TJSONData; AHeaders: TStringList);
    class procedure ExtractCSVRow(AData: TJSONData; AHeaders: TStringList; ARow: TStringList);
    class function JSONToCSV(AData: TJSONData): string;
    class function GetIndent(ADepth: Integer): string;
    class function EscapeXML(const AStr: string): string;
    class function EscapeYAMLString(const AStr: string): string;
    class function EscapeCSV(const AStr: string): string;
  public
    class function ExportString(const AJSONString: string; AFormat: TExportFormat): string;
    class procedure ExportToFile(const AJSONString: string; AFormat: TExportFormat; const AFileName: string);
    class function GetDefaultExtension(AFormat: TExportFormat): string;
    class function GetFilter(AFormat: TExportFormat): string;
  end;

implementation

{ TDataExporter }

class function TDataExporter.GetIndent(ADepth: Integer): string;
begin
  Result := StringOfChar(' ', ADepth * 2);
end;

class function TDataExporter.EscapeXML(const AStr: string): string;
begin
  Result := StringReplace(AStr, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '&quot;', [rfReplaceAll]);
  Result := StringReplace(Result, '''', '&apos;', [rfReplaceAll]);
end;

class function TDataExporter.EscapeYAMLString(const AStr: string): string;
begin
  if (Pos(#10, AStr) > 0) or (Pos(':', AStr) > 0) or (Pos('"', AStr) > 0) then
  begin
    Result := StringReplace(AStr, '\', '\\', [rfReplaceAll]);
    Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
    Result := '"' + Result + '"';
  end
  else
    Result := AStr;
end;

class function TDataExporter.EscapeCSV(const AStr: string): string;
begin
  if (Pos(',', AStr) > 0) or (Pos('"', AStr) > 0) or (Pos(#13, AStr) > 0) or (Pos(#10, AStr) > 0) then
    Result := '"' + StringReplace(AStr, '"', '""', [rfReplaceAll]) + '"'
  else
    Result := AStr;
end;

class function TDataExporter.JSONToXML(AData: TJSONData; const ARootName: string; ABeautify: Boolean; ADepth: Integer = 0): string;
var
  I: Integer;
  Indent, ChildIndent, LineBreak: string;
  KeyName: string;
begin
  if ABeautify then
  begin
    Indent := GetIndent(ADepth);
    ChildIndent := GetIndent(ADepth + 1);
    LineBreak := sLineBreak;
  end
  else
  begin
    Indent := '';
    ChildIndent := '';
    LineBreak := '';
  end;

  case AData.JSONType of
    jtObject:
      begin
        Result := Indent + '<' + ARootName + '>' + LineBreak;
        for I := 0 to AData.Count - 1 do
        begin
          KeyName := TJSONObject(AData).Names[I];
          if KeyName = '' then KeyName := 'item';
          // Sanitize key name for XML
          KeyName := StringReplace(KeyName, ' ', '_', [rfReplaceAll]);
          Result := Result + JSONToXML(AData.Items[I], KeyName, ABeautify, ADepth + 1);
        end;
        Result := Result + Indent + '</' + ARootName + '>' + LineBreak;
      end;
    jtArray:
      begin
        Result := '';
        for I := 0 to AData.Count - 1 do
          Result := Result + JSONToXML(AData.Items[I], ARootName, ABeautify, ADepth);
      end;
    jtString:
      Result := Indent + '<' + ARootName + '>' + EscapeXML(AData.AsString) + '</' + ARootName + '>' + LineBreak;
    jtNumber, jtBoolean:
      Result := Indent + '<' + ARootName + '>' + AData.AsString + '</' + ARootName + '>' + LineBreak;
    jtNull:
      Result := Indent + '<' + ARootName + ' xsi:nil="true"/>' + LineBreak;
    else
      Result := Indent + '<' + ARootName + '>' + EscapeXML(AData.AsString) + '</' + ARootName + '>' + LineBreak;
  end;
end;

class function TDataExporter.JSONToYAML(AData: TJSONData; ADepth: Integer = 0): string;
var
  I: Integer;
  Indent: string;
begin
  Indent := GetIndent(ADepth);
  Result := '';
  
  case AData.JSONType of
    jtObject:
      begin
        if AData.Count = 0 then
        begin
          Result := '{}' + sLineBreak;
          Exit;
        end;
        if ADepth > 0 then Result := Result + sLineBreak;
        for I := 0 to AData.Count - 1 do
        begin
          Result := Result + Indent + TJSONObject(AData).Names[I] + ': ';
          if (AData.Items[I].JSONType = jtObject) or (AData.Items[I].JSONType = jtArray) then
            Result := Result + JSONToYAML(AData.Items[I], ADepth + 1)
          else
            Result := Result + JSONToYAML(AData.Items[I], 0);
        end;
      end;
    jtArray:
      begin
        if AData.Count = 0 then
        begin
          Result := '[]' + sLineBreak;
          Exit;
        end;
        if ADepth > 0 then Result := Result + sLineBreak;
        for I := 0 to AData.Count - 1 do
        begin
          Result := Result + Indent + '- ';
          if (AData.Items[I].JSONType = jtObject) or (AData.Items[I].JSONType = jtArray) then
            Result := Result + JSONToYAML(AData.Items[I], ADepth + 1)
          else
            Result := Result + JSONToYAML(AData.Items[I], 0);
        end;
      end;
    jtString:
      Result := EscapeYAMLString(AData.AsString) + sLineBreak;
    jtNumber, jtBoolean:
      Result := AData.AsString + sLineBreak;
    jtNull:
      Result := 'null' + sLineBreak;
  end;
end;

class function TDataExporter.JSONToTOML(AData: TJSONData; const APrefix: string = ''): string;
var
  I: Integer;
  Key, NewPrefix: string;
begin
  Result := '';
  if AData.JSONType = jtObject then
  begin
    // First print simple key-values
    for I := 0 to AData.Count - 1 do
    begin
      if not ((AData.Items[I].JSONType = jtObject) or (AData.Items[I].JSONType = jtArray)) then
      begin
        Key := TJSONObject(AData).Names[I];
        if AData.Items[I].JSONType = jtString then
          Result := Result + Key + ' = "' + StringReplace(AData.Items[I].AsString, '"', '\"', [rfReplaceAll]) + '"' + sLineBreak
        else
          Result := Result + Key + ' = ' + AData.Items[I].AsString + sLineBreak;
      end;
    end;
    
    // Then print nested objects
    for I := 0 to AData.Count - 1 do
    begin
      if AData.Items[I].JSONType = jtObject then
      begin
        Key := TJSONObject(AData).Names[I];
        if APrefix = '' then NewPrefix := Key else NewPrefix := APrefix + '.' + Key;
        Result := Result + sLineBreak + '[' + NewPrefix + ']' + sLineBreak;
        Result := Result + JSONToTOML(AData.Items[I], NewPrefix);
      end;
      // TOML Arrays of tables are complex, skipping full implementation for simplicity
    end;
  end;
end;

class procedure TDataExporter.ExtractCSVHeaders(AData: TJSONData; AHeaders: TStringList);
var
  I: Integer;
  Key: string;
begin
  if AData.JSONType = jtObject then
  begin
    for I := 0 to AData.Count - 1 do
    begin
      Key := TJSONObject(AData).Names[I];
      if AHeaders.IndexOf(Key) < 0 then
        AHeaders.Add(Key);
    end;
  end;
end;

class procedure TDataExporter.ExtractCSVRow(AData: TJSONData; AHeaders: TStringList; ARow: TStringList);
var
  I: Integer;
  Val: TJSONData;
begin
  ARow.Clear;
  for I := 0 to AHeaders.Count - 1 do
  begin
    if AData.JSONType = jtObject then
    begin
      Val := TJSONObject(AData).Find(AHeaders[I]);
      if Assigned(Val) then
      begin
        if (Val.JSONType = jtObject) or (Val.JSONType = jtArray) then
          ARow.Add(EscapeCSV(Val.AsJSON))
        else if Val.JSONType = jtNull then
          ARow.Add('')
        else
          ARow.Add(EscapeCSV(Val.AsString));
      end
      else
        ARow.Add('');
    end
    else
      ARow.Add('');
  end;
end;

class function TDataExporter.JSONToCSV(AData: TJSONData): string;
var
  Headers, Row: TStringList;
  I: Integer;
begin
  Result := '';
  if AData.JSONType <> jtArray then
  begin
    // If not array, just treat as single row
    Headers := TStringList.Create;
    Row := TStringList.Create;
    try
      ExtractCSVHeaders(AData, Headers);
      Result := Headers.CommaText + sLineBreak;
      ExtractCSVRow(AData, Headers, Row);
      Result := Result + Row.CommaText + sLineBreak;
    finally
      Headers.Free;
      Row.Free;
    end;
    Exit;
  end;

  Headers := TStringList.Create;
  Row := TStringList.Create;
  try
    // 1st pass: extract all headers
    for I := 0 to AData.Count - 1 do
      ExtractCSVHeaders(AData.Items[I], Headers);

    // Write headers
    for I := 0 to Headers.Count - 1 do
    begin
      Result := Result + EscapeCSV(Headers[I]);
      if I < Headers.Count - 1 then Result := Result + ',';
    end;
    Result := Result + sLineBreak;

    // 2nd pass: write rows
    for I := 0 to AData.Count - 1 do
    begin
      ExtractCSVRow(AData.Items[I], Headers, Row);
      Result := Result + Row.CommaText + sLineBreak;
    end;
  finally
    Headers.Free;
    Row.Free;
  end;
end;

class function TDataExporter.ExportString(const AJSONString: string; AFormat: TExportFormat): string;
var
  Data: TJSONData;
begin
  Result := '';
  if Trim(AJSONString) = '' then Exit;

  // Formats that don't strictly require parsing into fpjson
  if AFormat = efJSON then
  begin
    Result := AJSONString;
    Exit;
  end;
  if AFormat = efBeautifiedJSON then
  begin
    Result := BeautifyJSONString(AJSONString);
    Exit;
  end;
  if AFormat = efMinifiedJSON then
  begin
    // For large files, doing a full parse just to minify is expensive, but for now we can just strip whitespace
    // Or just use fpjson
    try
      Data := GetJSON(AJSONString);
      try
        Result := Data.AsJSON; // Default AsJSON is minified
      finally
        Data.Free;
      end;
    except
      Result := AJSONString;
    end;
    Exit;
  end;

  try
    Data := GetJSON(AJSONString);
    try
      case AFormat of
        efMinifiedXML: Result := '<?xml version="1.0" encoding="UTF-8"?>' + JSONToXML(Data, 'root', False);
        efBeautifiedXML: Result := '<?xml version="1.0" encoding="UTF-8"?>' + sLineBreak + JSONToXML(Data, 'root', True);
        efCSV: Result := JSONToCSV(Data);
        efYAML: Result := JSONToYAML(Data);
        efTOML: Result := JSONToTOML(Data);
      end;
    finally
      Data.Free;
    end;
  except
    on E: Exception do
      raise Exception.Create('Error parsing JSON for export: ' + E.Message);
  end;
end;

class procedure TDataExporter.ExportToFile(const AJSONString: string; AFormat: TExportFormat; const AFileName: string);
var
  OutputStr: string;
  FS: TFileStream;
  Bytes: TBytes;
begin
  OutputStr := ExportString(AJSONString, AFormat);
  FS := TFileStream.Create(AFileName, fmCreate);
  try
    if Length(OutputStr) > 0 then
    begin
      Bytes := TEncoding.UTF8.GetBytes(OutputStr);
      FS.WriteBuffer(Bytes[0], Length(Bytes));
    end;
  finally
    FS.Free;
  end;
end;

class function TDataExporter.GetDefaultExtension(AFormat: TExportFormat): string;
begin
  case AFormat of
    efJSON, efMinifiedJSON, efBeautifiedJSON: Result := 'json';
    efMinifiedXML, efBeautifiedXML: Result := 'xml';
    efCSV: Result := 'csv';
    efYAML: Result := 'yaml';
    efTOML: Result := 'toml';
    else Result := 'txt';
  end;
end;

class function TDataExporter.GetFilter(AFormat: TExportFormat): string;
begin
  case AFormat of
    efJSON, efMinifiedJSON, efBeautifiedJSON: 
      Result := 'JSON Files (*.json)|*.json|All Files (*.*)|*.*';
    efMinifiedXML, efBeautifiedXML: 
      Result := 'XML Files (*.xml)|*.xml|All Files (*.*)|*.*';
    efCSV: 
      Result := 'CSV Files (*.csv)|*.csv|All Files (*.*)|*.*';
    efYAML: 
      Result := 'YAML Files (*.yaml;*.yml)|*.yaml;*.yml|All Files (*.*)|*.*';
    efTOML: 
      Result := 'TOML Files (*.toml)|*.toml|All Files (*.*)|*.*';
    else 
      Result := 'All Files (*.*)|*.*';
  end;
end;

end.