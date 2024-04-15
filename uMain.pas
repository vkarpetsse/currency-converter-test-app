unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  Quick.Logger,
  Quick.Logger.Provider.Files,
  Quick.Logger.Provider.IDEDebug,
  Quick.Logger.Provider.Events,
  Quick.Threads, FMX.Memo.Types, FireDAC.Stan.Intf, FireDAC.Stan.Option,
  FireDAC.Stan.Error, FireDAC.UI.Intf, FireDAC.Phys.Intf, FireDAC.Stan.Def,
  FireDAC.Stan.Pool, FireDAC.Stan.Async, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.FMXUI.Wait, FireDAC.Stan.Param,
  FireDAC.DatS, FireDAC.DApt.Intf, FireDAC.DApt, Data.DB, FireDAC.Comp.DataSet,
  FireDAC.Comp.Client,
  IdTCPClient,
  IPPeerClient,REST.Client, Data.Bind.Components, Data.Bind.ObjectScope,
  REST.Types, FMX.Controls.Presentation, FMX.ScrollBox, FMX.Memo, FMX.Objects,
  FMX.StdCtrls, FMX.Edit, FMX.Layouts, FMX.ListBox;

type
{  TCurrencyData = record
    Key: string;
    Value: string;
  end;
  TAPIResponseData = record
    Key: string;
    Value: string;
  end; }
  TConvertCurrencyData = record
     Timestamp: integer;
     quote: Double;
     result: Double;
  end;
  TfrmMain = class(TForm)
    RESTClient1: TRESTClient;
    RESTRequest1: TRESTRequest;
    RESTResponse1: TRESTResponse;
    Memo1: TMemo;
    cbFrom: TComboBox;
    Header: TLayout;
    lblHeader: TLabel;
    FromTo: TGridPanelLayout;
    lblFrom: TLabel;
    lblTo: TLabel;
    cbTo: TComboBox;
    Main: TLayout;
    Amount: TLayout;
    edtAmount: TEdit;
    Result: TLayout;
    Label2: TLabel;
    Convert: TLayout;
    lblResultHeader: TLabel;
    lblResultValue: TLabel;
    lblExchangeRate: TLabel;
    Rectangle1: TRectangle;
    StyleBook1: TStyleBook;
    btnConvert: TButton;
    dbConvHistory: TFDConnection;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnConvertClick(Sender: TObject);
    procedure dbConvHistoryBeforeConnect(Sender: TObject);

  private
    { Private declarations }
    procedure ConfigureLogFile(const AFileName: string);
    procedure ClearResult(Sender: TObject);

  public
    { Public declarations }
    function GetCurrenciesFromAPI(const AAccess_key: string): TStrings;
    function GetConvertCurrency(const AAccess_key: string; const AFrom: string; const ATo: string; AAmount: Currency;
                                out AConvertCurrencyData: TConvertCurrencyData): boolean;
  end;

const
  LOGFILENAME = 'CurrencyConverter.log';
  ACCESS_KEY = '8250ef116751f90dd4b394bece3c72d4';


  function CheckInternetConnection(const AHost: string; const APort: integer; out AErrorMessage: string): boolean;
  function UnQuote(Text: string): string; inline;
var
  frmMain: TfrmMain;

implementation

uses System.JSON, FMX.DialogService;

{$R *.fmx}

function UnQuote(Text: string): string; inline;
begin
  if ( Text.StartsWith('"') or Text.StartsWith('''') ) then
  begin
    if ( Text.EndsWith('"') or Text.EndsWith('''') ) then
      exit( copy(Text, 2, Text.Length-2) );
  end;
  result := Text;
end;

function CheckInternetConnection(const AHost: string; const APort: integer; out AErrorMessage: string): boolean;
var
  LIdTCPClient: TIdTCPClient;
begin
  Result := False;
  LIdTCPClient := TIdTCPClient.Create(nil);
  try
    LIdTCPClient.ReadTimeout := 2000;
    LIdTCPClient.ConnectTimeout := 2000;
    LIdTCPClient.Port := APort;
    LIdTCPClient.Host := AHost;
    try
      LIdTCPClient.Connect;
      LIdTCPClient.Disconnect;
      Result := True;
    except
      on E:Exception do begin
        AErrorMessage := format('%s: %s', [E.ClassName, E.Message]);
      end;
      end;
  finally
    LIdTCPClient.DisposeOf; // use it for mobile
    LIdTCPClient := nil;
  end;
end;

function GetResponseSuccessStatus(const AResponseContent: string): boolean;
var
  LJSONPair: TJSONPair;
begin
  Result := False;
  var jsv := TJSONObject.ParseJSONValue(AResponseContent) as TJSONObject;
  try
    LJSONPair :=  jsv.Get('success');
    {$IFDEF DEBUG}
    var LSuccessStr := LJSONPair.JsonValue.ToString;
    {$ENDIF}
    Result := LJSONPair.JsonValue.ToString = 'true';
    if not Result then
    begin
      LJSONPair :=  jsv.Get('error');
      var LErrorCode := (LJSONPair.JsonValue as TJSONObject).GetValue('code').ToString;
      var LErrorType := (LJSONPair.JsonValue as TJSONObject).GetValue('type').ToString;
      var LErrorInfo := (LJSONPair.JsonValue as TJSONObject).GetValue('type').ToString;
      Log('Error [code, type, info]: s%, %s, %s', [LErrorInfo], etError);
    end;
  finally
    jsv.DisposeOf;
  end;
end;

function TfrmMain.GetCurrenciesFromAPI(const AAccess_key: string): TStrings;
var
  LJSONPair: TJSONPair;
  LSuccess: boolean;
  LCurrency: string;
begin
  Result := TStringList.Create;
  RESTClient1.BaseURL := format('http://api.currencylayer.com/list?access_key=%s', [AAccess_key]);
  try
    RESTRequest1.Execute;
    if RESTResponse1.StatusCode = 200 then
    begin
      var LSuccessStatus := GetResponseSuccessStatus(RESTResponse1.Content);
      if LSuccessStatus then
      begin
        var jsv := TJSONObject.ParseJSONValue(RESTResponse1.Content) as TJSONObject;
        try
          var jp := jsv.Get('currencies');

          if jp.JsonValue is TJSONObject then
          for var i: integer := 0 to TJSONObject(jp.JsonValue).Count - 1 do
          begin
            var LValue := UnQuote(TJSONObject(jp.JsonValue).Pairs[i].JsonString.ToString) + '  ' +
                          UnQuote(TJSONObject(jp.JsonValue).Pairs[i].JsonValue.ToString);
            Result.Add(LValue);
          end;
        finally
          jsv.DisposeOf;
        end;
      end;
    end;
  except
    on E:Exception do
    begin
      Log('Error GetCurrenciesFromAPI: %s %s', [E.ClassName, E.Message], etError);
    end;
  end;
end;

function TfrmMain.GetConvertCurrency(const AAccess_key: string; const AFrom: string; const ATo: string; AAmount: Currency;
                                     out AConvertCurrencyData: TConvertCurrencyData): boolean;
begin
  Result := False;
  RESTClient1.BaseURL := format('http://api.currencylayer.com/convert?access_key=%s&from=%s&to=%s&amount=%f', [AAccess_key, AFrom, ATo, AAmount]);
  try
    RESTRequest1.Execute;
    if RESTResponse1.StatusCode = 200 then
    begin
      var LSuccessStatus := GetResponseSuccessStatus(RESTResponse1.Content);
      if LSuccessStatus then
      begin
        var jsv := TJSONObject.ParseJSONValue(RESTResponse1.Content) as TJSONObject;
        try
          var LJSONPair := jsv.Get('info');
          var LTimestamp := (LJSONPair.JsonValue as TJSONObject).GetValue('timestamp').ToString;
          var LQuote := (LJSONPair.JsonValue as TJSONObject).GetValue('quote').ToString;
          LJSONPair := jsv.Get('result');
          var LResult := LJSONPair.JsonValue.ToString;
          AConvertCurrencyData.Timestamp := StrToInt(LTimestamp);
          AConvertCurrencyData.quote := StrToFloat(LQuote);
          AConvertCurrencyData.result := StrToFloat(LResult);
          Result := True;
        finally

        end;
      end else
        Result := False;
    end;
  except
    on E:Exception do
    begin
      Log('Error ConvertCurrency: %s %s', [E.ClassName, E.Message], etError);
    end;
  end;
end;

procedure TfrmMain.btnConvertClick(Sender: TObject);
begin
  if (cbFrom.ItemIndex < 0) or (cbTo.ItemIndex < 0) then
  begin
    TDialogService.ShowMessage('Please select currency');
    Exit;
  end;

  if StrToCurrDef(edtAmount.Text, 0) = 0 then
  begin
    TDialogService.ShowMessage('Please input correct amount');
    Exit;
  end;


  var LFrom := Copy(cbFrom.Items[cbFrom.ItemIndex], 1, 3);
  var LTo := Copy(cbFrom.Items[cbTo.ItemIndex], 1, 3);
  var LCurrency := StrToCurr(edtAmount.Text);

  var LConvertCurrencyData : TConvertCurrencyData;
  var ConvertCurrencyResult := GetConvertCurrency(ACCESS_KEY, LFrom, LTo, LCurrency, LConvertCurrencyData);
  if ConvertCurrencyResult then
  begin
    lblResultValue.Text := FloatToStr(LConvertCurrencyData.result);
    lblExchangeRate.Text := format('Exchange Rate: %s', [FloatToStr(LConvertCurrencyData.quote)]);

    if dbConvHistory.Connected then
    begin
      //

      // create table tblConvHistory if not exists
      var LqryCreateConvHistoryTable  := TFDQuery.Create(nil);
      LqryCreateConvHistoryTable.Connection := dbConvHistory;
      try
        LqryCreateConvHistoryTable.SQL.Add('CREATE TABLE IF NOT EXISTS tblConvHistory (');
        LqryCreateConvHistoryTable.SQL.Add('Id	INTEGER NOT NULL, createdAt	INTEGER NOT NULL,');
        LqryCreateConvHistoryTable.SQL.Add('source_currency	VARCHAR(3) NOT NULL, dest_currency	VARCHAR(3) NOT NULL,');
        LqryCreateConvHistoryTable.SQL.Add('source_amount	REAL NOT NULL, quote	REAL NOT NULL, dest_amount	REAL NOT NULL,');
        LqryCreateConvHistoryTable.SQL.Add('PRIMARY KEY(Id AUTOINCREMENT))');
        try
          LqryCreateConvHistoryTable.ExecSQL;
        except
          on E:Exception do
            Log('Error: %s %s', [E.ClassName, E.Message], etError);
        end;
      finally
        LqryCreateConvHistoryTable.DisposeOf;
      end;

       var LqryAddConversionLogResult := TFDQuery.Create(nil);
      LqryAddConversionLogResult.Connection := dbConvHistory;
      try

        LqryAddConversionLogResult.SQL.Add('INSERT INTO tblConvHistory(createdAt,	source_currency, dest_currency, source_amount, quote, dest_amount)');
        LqryAddConversionLogResult.SQL.Add('VALUES(:createdAt,	:source_currency, :dest_currency, :source_amount, :quote, :dest_amount)');
        LqryAddConversionLogResult.ParamByName('createdAt').AsInteger := LConvertCurrencyData.Timestamp;
        LqryAddConversionLogResult.ParamByName('source_currency').AsString := LFrom;
        LqryAddConversionLogResult.ParamByName('dest_currency').AsString := LTo;
        LqryAddConversionLogResult.ParamByName('source_amount').AsFloat := LCurrency;
        LqryAddConversionLogResult.ParamByName('quote').AsFloat := LConvertCurrencyData.quote;
        LqryAddConversionLogResult.ParamByName('dest_amount').AsFloat := LConvertCurrencyData.result;
        try
          LqryAddConversionLogResult.ExecSQL;
        except
          on E:Exception do
          begin
            Log('Error: %s %s', [E.ClassName, E.Message], etError);
          end;
        end;
      finally
        LqryAddConversionLogResult.DisposeOf;
      end;
    end;
  end;

end;

procedure TfrmMain.ClearResult(Sender: TObject);
begin
  lblResultValue.Text := EmptyStr;
  lblExchangeRate.Text := EmptyStr;
end;

procedure TfrmMain.ConfigureLogFile(const AFileName: string);
begin
   //Add Log File provider
  Logger.Providers.Add(GlobalLogFileProvider);
  //Configure provider
  GlobalLogFileProvider.FileName := Format('%s', [AFileName]);
  GlobalLogFileProvider.LogLevel := LOG_ALL;
  GlobalLogFileProvider.TimePrecission := True;
  GlobalLogFileProvider.MaxRotateFiles := 3;
  GlobalLogFileProvider.MaxFileSizeInMB := 5;
  GlobalLogFileProvider.Enabled := True;
end;

procedure TfrmMain.dbConvHistoryBeforeConnect(Sender: TObject);
begin
{$IF DEFINED(iOS) or DEFINED(ANDROID)}
  FDBConvHistory.Params.Values['Database'] := TPath.Combine(TPath.GetDocumentsPath, ADatabaseName);
  {$ENDIF}
end;

procedure TfrmMain.FormCreate(Sender: TObject);
 const
   LHost = 'google.com';
   LPort = 80;
begin
  {$IFDEF DEBUG}
  Log('FormCreate event begin', etInfo);
  {$ENDIF}
   ConfigureLogFile(LOGFILENAME);

   try
     dbConvHistory.Open;
     Log('Connect to database % is successful', [dbConvHistory.Params.Values['Database']], etInfo);
   except
     on E:Exception do
       Log('Cannot connect to database %s. %s', [dbConvHistory.Params.Values['Database'], E.Message], etError);
   end;

  var LOutputErrorMessage := EmptyStr;
  if not CheckInternetConnection(LHost, LPort, LOutputErrorMessage) then
  begin
    Log('Error connect to %s:%d. %s', [LHost, LPort, LOutputErrorMessage], etError);
  end;

  // Fills Currencies Boxes
  var LCurrenciesList := GetCurrenciesFromAPI(ACCESS_KEY);
  try
    if LCurrenciesList.Count > 0 then
    begin
      cbFrom.Items.Assign(LCurrenciesList);
      cbTo.Items.Assign(LCurrenciesList);
//      for var idx := 0 to pred(LCurrenciesList.Count) do
//      begin
//        cbFrom.Items.AddObject(LCurrenciesList[idx], LCurrenciesList.Objects[idx]);
//        cbTo.Items.AddObject(LCurrenciesList[idx], LCurrenciesList.Objects[idx]);
//      end;
    end;
  finally
    LCurrenciesList.DisposeOf;
  end;

  cbFrom.OnChange := ClearResult;
  cbTo.OnChange := ClearResult;
  edtAmount.OnChange := ClearResult;

  {$IFDEF DEBUG}
  Log('FormCreate event end', etInfo);
  {$ENDIF}
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  {$IFDEF DEBUG}
  Log('FormDestroy event begin', etInfo);
  {$ENDIF}

  if dbConvHistory.Connected then
    dbConvHistory.Close;
  {$IFDEF DEBUG}
  Log('FormDestroy event end', etInfo);
  {$ENDIF}
end;

end.
