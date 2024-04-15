{ ***************************************************************************

  Copyright (c) 2016-2019 Kike P�rez

  Unit        : Quick.Logger.UnhandledExceptionHook
  Description : Log Unhandled Exceptions
  Author      : Kike P�rez
  Version     : 1.20
  Created     : 28/03/2019
  Modified    : 28/03/2019

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
unit Quick.Logger.UnhandledExceptionHook;

{$i QuickLib.inc}

interface

implementation

uses
  SysUtils,
  TypInfo,
  Quick.Logger;

procedure UnhandledException(ExceptObject : TObject; ExceptAddr : Pointer);
begin
  if Assigned(GlobalLoggerUnhandledException) then GlobalLoggerUnhandledException(ExceptObject,ExceptAddr);
end;

initialization

  ExceptProc := @UnhandledException; //unhandled exceptions

end.
