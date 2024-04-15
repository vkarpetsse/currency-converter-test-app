{ ***************************************************************************

  Copyright (c) 2016-2020 Kike P�rez

  Unit        : Quick.Logger.Provider.Logstash
  Description : Log Api Logstash Provider
  Author      : Kike P�rez
  Version     : 1.0
  Created     : 20/02/2019
  Modified    : 24/04/2020

  This file is part of QuickLogger: https://github.com/exilon/QuickLogger

 ***************************************************************************

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

 *************************************************************************** }
unit Quick.Logger.Provider.Logstash;

{$i QuickLib.inc}

interface

uses
  Classes,
  SysUtils,
  Quick.HttpClient,
  Quick.Commons,
  Quick.Logger;

type

  TLogLogstashProvider = class (TLogProviderBase)
  private
    fHTTPClient : TJsonHTTPClient;
    fURL : string;
    fFullURL : string;
    fIndexName : string;
    fDocType : string;
    fUserAgent : string;
  public
    constructor Create; override;
    destructor Destroy; override;
    property URL : string read fURL write fURL;
    property IndexName : string read fIndexName write fIndexName;
    property DocType : string read fDocType write fDocType;
    property UserAgent : string read fUserAgent write fUserAgent;
    property JsonOutputOptions : TJsonOutputOptions read fJsonOutputOptions write fJsonOutputOptions;
    procedure Init; override;
    procedure Restart; override;
    procedure WriteLog(cLogItem : TLogItem); override;
  end;

var
  GlobalLogLogstashProvider : TLogLogstashProvider;

implementation

constructor TLogLogstashProvider.Create;
begin
  inherited;
  LogLevel := LOG_ALL;
  fURL := 'http://localhost:5044';
  fIndexName := 'logger';
  fDocType := 'doc';
  fJsonOutputOptions.UseUTCTime := True;
  fUserAgent := DEF_USER_AGENT;
  IncludedInfo := [iiAppName,iiHost,iiEnvironment];
end;

destructor TLogLogstashProvider.Destroy;
begin
  if Assigned(fHTTPClient) then FreeAndNil(fHTTPClient);

  inherited;
end;

procedure TLogLogstashProvider.Init;
begin
  fFullURL := Format('%s/%s/%s',[fURL,fIndexName,fDocType]);
  fHTTPClient := TJsonHTTPClient.Create;
  fHTTPClient.ContentType := 'application/json';
  fHTTPClient.UserAgent := fUserAgent;
  fHTTPClient.HandleRedirects := True;
  inherited;
end;

procedure TLogLogstashProvider.Restart;
begin
  Stop;
  if Assigned(fHTTPClient) then FreeAndNil(fHTTPClient);
  Init;
end;

procedure TLogLogstashProvider.WriteLog(cLogItem : TLogItem);
var
  resp : IHttpRequestResponse;
begin
  if CustomMsgOutput then resp := fHTTPClient.Post(fFullURL,LogItemToFormat(cLogItem))
    else resp := fHTTPClient.Post(fFullURL,LogItemToJson(cLogItem));

  if not (resp.StatusCode in [200,201]) then
    raise ELogger.Create(Format('[TLogLogstashProvider] : Response %d : %s trying to post event',[resp.StatusCode,resp.StatusText]));
end;

initialization
  GlobalLogLogstashProvider := TLogLogstashProvider.Create;

finalization
  if Assigned(GlobalLogLogstashProvider) and (GlobalLogLogstashProvider.RefCount = 0) then GlobalLogLogstashProvider.Free;

end.
