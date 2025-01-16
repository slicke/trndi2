
(*
 * This file is part of Trndi (https://github.com/slicke/trndi).
 * Copyright (c) 2021-2025 Björn Lindh.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, version 3.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 * ---------
 *
 * GitHub: https://github.com/slicke/trndi
 *)

unit trndi.api.xdrip;

{$mode ObjFPC}{$H+}

interface

uses 
Classes, SysUtils, strutils, sha1, nsapi, trndi.native, trndi.types, dateutils,
dialogs;

const 
  XDRIP_READINGS = 'sgv.json';
  XDRIP_STATUS = 'pebble';
  XDRIP_RANGES = 'status.json';
  // This contains the current timestamp of the server

type 
  xDrip = class(NightScout)
    public 
      constructor create(user, pass, extra: string);
      override;
      function getReadings(min, maxNum: integer; path: string = ''): BGResults;
      override;
      function connect: boolean;
      override;
  end;

implementation

constructor xDrip.create(user, pass, extra: string);
begin
  ua      := 'Mozilla/5.0 (compatible; trndi) TrndiAPI';
  baseUrl := TrimRightSet(user, ['/']) + '/';

  key     := IfThen(pass <> '', 'api-secret=' + SHA1Print(SHA1String(pass)), '');

  timezone := GetLocalTimeOffset;
  native := TrndiNative.create(ua, baseUrl);
end;

function xDrip.getReadings(min, maxNum: integer; path: string = ''): BGResults;
begin
  if path = '' then path := XDRIP_READINGS;

  result := inherited getReadings(min, maxNum, path);
end;

function xDrip.connect: boolean;

var 
  y:  string;
  td: tdatetime;
  t: int64;
  i: integer;
begin
  if Copy(baseUrl, 1, 4) <> 'http' then
    begin
      result := false;
      lasterr := 'Invalid address. It must start with http:// or https://!';
      Exit;
    end;
  y := native.request(false, XDRIP_STATUS, [], '', key);

  if pos('uthentication failed', y) > 0 then
    begin
      lasterr := 'Acess token rejected by xDrip, is it correct?';
      Result := false;
      Exit;
    end;

  y := copy(y, pos('"now":', y) + 6, 13);
  if not TryStrToInt64(y,t) then
    begin
      lasterr := 'xDrip could not initialize. Unable to synx clocks, xDrip may be offline.';
      Result := false;
      Exit;
    end;

  td := UnixToDateTime(t div 1000);
  timeDiff := SecondsBetween(td, LocalTimeToUniversal(now));
  if timeDiff < 0 then
    timeDiff := 0;

  timeDiff := -1 * timeDiff;

  y := native.request(false, XDRIP_RANGES, [], '', key);
  if TryStrToInt(TrimSet(copy(y, pos('bgHigh', y) + 8, 4), [' ',',']), i) then
    cgmHi := i
  else
    cgmHi := 160;

  if TryStrToInt(TrimSet(copy(y, pos('bgLow', y) + 7, 4), [' ',',', '}']), i) then
    cgmLo := i
  else
    cgmLo := 60;

  cgmRangeHi := 500;
  cgmRangeLo := 0;
  result   := true;
end;

end.
