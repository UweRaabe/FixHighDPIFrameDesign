unit FixHighDPIFrameDesign.Handler;

interface

procedure Register;

implementation

uses
  System.SysUtils, System.IOUtils, System.Classes,
  ToolsAPI, FixHighDPIFrameDesign.Images;

{$WARN SYMBOL_PLATFORM OFF}

resourcestring
  SDescription = 'Fixes wrong scaling when opening inherited frames in High DPI designer';

type
  TFrameDfmHandler = class
  private
    FContent: TStringList;
    FFileName: string;
    FModified: Boolean;
    FOriginalFormat: TStreamOriginalFormat;
    procedure CheckRootProp(const AName, AValue: string);
    function CheckValidInheritedFrameLine(const Line: string): Boolean;
    function IsNonRootTrigger(const ALine: string): Boolean;
    procedure RemoveRootProp(const AName, AValue: string);
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    procedure CheckMissingProperties;
    procedure RemoveAddedProperties;
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
    property Content: TStringList read FContent;
    property FileName: string read FFileName;
  end;

type
  TFixNotifier = class(TNotifierObject, IOTANotifier, IOTAIDENotifier)
  strict private
  private
    procedure CheckDFMOpened(const AFileName: string);
    procedure CheckDFMOpening(const AFileName: string);
    function HasWritableDFM(const AFileName: string; out ADfmName: string): Boolean;
  public
    procedure AfterCompile(Succeeded: Boolean); overload;
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
  end;

type
  TFixHandler = class
  private
  const
    cCopyright = 'Copyright© 2025 Uwe Raabe' + sLineBreak +
                 'http://www.uweraabe.de/';
    cIconName = 'FixHighDPIFrameDesign';
    cTitle = 'Fix High DPI Frame Design';
    cVersion = 'V1.0.0';
  class var
    FInstance: TFixHandler;
  var
    FNotifierID: Integer;
    FPluginInfoID: Integer;
    FVersion: string;
    function GetDescription: string;
    function GetOTAAboutBoxServices: IOTAAboutBoxServices;
    function GetOTAServices: IOTAServices;
    function GetTitle: string;
    function GetVersion: string;
  public
    constructor Create;
    destructor Destroy; override;
    class function AppVersion: string; static;
    class procedure CreateInstance;
    class procedure DestroyInstance;
    property Description: string read GetDescription;
    property OTAAboutBoxServices: IOTAAboutBoxServices read GetOTAAboutBoxServices;
    property OTAServices: IOTAServices read GetOTAServices;
    property Title: string read GetTitle;
    property Version: string read GetVersion;
  end;

procedure Register;
begin
  TFixHandler.CreateInstance;
end;

constructor TFixHandler.Create;
begin
  inherited;
  dmImages := TdmImages.Create(nil);
  var images := dmImages.ImageArray[cIconName];
  SplashScreenServices.AddPluginBitmap(Title, images, False, '', '');
  FPluginInfoID := OTAAboutBoxServices.AddPluginInfo(Title, Description, images);
  FNotifierID := OTAServices.AddNotifier(TFixNotifier.Create);
end;

destructor TFixHandler.Destroy;
begin
  if FNotifierID > 0 then begin
    OTAServices.RemoveNotifier(FNotifierID);
  end;
  dmImages.Free;
  dmImages := nil;
  inherited;
end;

class function TFixHandler.AppVersion: string;
var
  build: Cardinal;
  major: Cardinal;
  minor: Cardinal;
begin
  if GetProductVersion(GetModuleName(HInstance), major, minor, build) then begin
    Result := Format('V%d.%d.%d', [major, minor, build]); // do not localize
  end
  else begin
    Result := cVersion;
  end;
end;

class procedure TFixHandler.CreateInstance;
begin
  FInstance := TFixHandler.Create;
end;

class procedure TFixHandler.DestroyInstance;
begin
  FInstance.Free;
end;

function TFixHandler.GetDescription: string;
begin
  Result := SDescription + sLineBreak + sLineBreak + cCopyRight;
end;

function TFixHandler.GetOTAAboutBoxServices: IOTAAboutBoxServices;
begin
  Result := BorlandIDEServices.GetService(IOTAAboutBoxServices) as IOTAAboutBoxServices;
end;

function TFixHandler.GetOTAServices: IOTAServices;
begin
  result := BorlandIDEServices.GetService(IOTAServices) as IOTAServices;
end;

function TFixHandler.GetTitle: string;
begin
  Result := cTitle + ' ' + Version;
end;

function TFixHandler.GetVersion: string;
begin
  if FVersion = '' then begin
    FVersion := AppVersion;
  end;
  Result := FVersion;
end;

procedure TFixNotifier.AfterCompile(Succeeded: Boolean);
begin
end;

procedure TFixNotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean);
begin
end;

procedure TFixNotifier.CheckDFMOpened(const AFileName: string);
var
  dfmName: string;
begin
  if HasWritableDFM(AFileName, dfmName) then begin
    var handler := TFrameDfmHandler.Create(dfmName);
    try
      handler.RemoveAddedProperties;
    finally
      handler.Free;
    end;
  end;
end;

procedure TFixNotifier.CheckDFMOpening(const AFileName: string);
var
  dfmName: string;
begin
  if HasWritableDFM(AFileName, dfmName) then begin
    var handler := TFrameDfmHandler.Create(dfmName);
    try
      handler.CheckMissingProperties;
    finally
      handler.Free;
    end;
  end;
end;

procedure TFixNotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
begin
  { Make temporary changes to the DFM during opening in the IDE
    and restore them after the file has been opened. }
  case NotifyCode of
    ofnFileOpening: CheckDFMOpening(FileName);
    ofnFileOpened: CheckDFMOpened(FileName);
  end;
end;

function TFixNotifier.HasWritableDFM(const AFileName: string; out ADfmName: string): Boolean;
begin
  Result := False;
  if SameText(TPath.GetExtension(AFileName), '.pas') then begin
    ADfmName := TPath.ChangeExtension(AFileName, '.dfm');
    Result := TFile.Exists(ADfmName) and not (TFileAttribute.faReadOnly in TFile.GetAttributes(ADfmName));
  end;
end;

constructor TFrameDfmHandler.Create(const AFileName: string);
begin
  inherited Create;
  LoadFromFile(AFileName);
end;

destructor TFrameDfmHandler.Destroy;
begin
  if FModified then
    SaveToFile(FileName);
  FContent.Free;
  inherited Destroy;
end;

procedure TFrameDfmHandler.CheckMissingProperties;
begin
  CheckRootProp('PixelsPerInch', '96');
end;

procedure TFrameDfmHandler.RemoveAddedProperties;
begin
  RemoveRootProp('PixelsPerInch', '96');
end;

procedure TFrameDfmHandler.CheckRootProp(const AName, AValue: string);

var
  LeadIn: string;
begin
  LeadIn := '  ' + AName + ' = ';
  for var I := 0 to Content.Count - 1 do begin
    var line := Content[I];
    if not CheckValidInheritedFrameLine(line) then Break;

    { check for existing property with any value }
    if line.StartsWith(LeadIn) then Break;

    { now children are following and we need to insert the property }
    if IsNonRootTrigger(line) then begin
      Content.Insert(I, LeadIn + AValue);
      FModified := True;
      Break;
    end;
  end;
end;

function TFrameDfmHandler.CheckValidInheritedFrameLine(const Line: string): Boolean;
begin
  Result := False;

  { inherited frames start with inherited in the first line }
  if line.StartsWith('object') then Exit;

  { TextHeight is only (and always) present in a form }
  if line.StartsWith('  TextHeight = ') then Exit;

  Result := True;
end;

function TFrameDfmHandler.IsNonRootTrigger(const ALine: string): Boolean;
const
  { leading blanks (indentation) is crucial!
    The two spaces are hard coded in System.Classes.
  }
  cTriggers: TArray<string> = ['  object ', '  inherited ', '  inline ', 'end'];
begin
  Result := True;
  for var S in cTriggers do begin
    if ALine.StartsWith(S) then
      Exit;
  end;
  Result := False;
end;

procedure TFrameDfmHandler.RemoveRootProp(const AName, AValue: string);
var
  I: Integer;
  LeadIn: string;
  line: string;
begin
  LeadIn := '  ' + AName + ' = ' + AValue;
  { skip first line! }
  for I := 1 to Content.Count - 1 do begin
    line := Content[I];
    if not CheckValidInheritedFrameLine(line) then Break;

    { when only children are following there is nothing to remove }
    if IsNonRootTrigger(line) then Break;

    { check for property name and value }
    if line.StartsWith(LeadIn) then begin
      Content.Delete(I);
      FModified := True;
      Break;
    end;
  end;
end;

procedure TFrameDfmHandler.LoadFromFile(const AFileName: string);
var
  inStream: TFileStream;
  txtStream: TMemoryStream;
begin
  FFileName := AFileName;
  FOriginalFormat := sofUnknown;
  inStream := TFileStream.Create(FFileName, fmOpenRead);
  try
    txtStream := TMemoryStream.Create;
    try
      ObjectBinaryToText(inStream, txtStream, FOriginalFormat);
      txtStream.Position := 0;
      FContent := TStringList.Create();
      FContent.LoadFromStream(txtStream);
    finally
      txtStream.Free;
    end;
  finally
    inStream.Free;
  end;
end;

procedure TFrameDfmHandler.SaveToFile(const AFileName: string);
var
  outStream: TFileStream;
  txtStream: TMemoryStream;
  lastWrite: TDateTime;
begin
  lastWrite := TFile.GetLastWriteTime(AFileName);
  if FOriginalFormat = sofBinary then begin
    outStream := TFileStream.Create(AFileName, fmCreate);
    try
      txtStream := TMemoryStream.Create;
      try
        FContent.SaveToStream(txtStream);
        txtStream.Position := 0;
        ObjectTextToBinary(txtStream, outStream);
      finally
        txtStream.Free;
      end;
    finally
      outStream.Free;
    end;
  end
  else begin
    Content.SaveToFile(AFileName);
  end;
  { To avoid triggering a "file has changed" in the IDE }
  TFile.SetLastWriteTime(AFileName, lastWrite);
end;

initialization
finalization
  TFixHandler.DestroyInstance;
end.
