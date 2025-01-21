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

unit umain;

{$mode objfpc}{$H+}

interface

uses
Classes, Menus, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
dexapi, nsapi, trndi.types, math, DateUtils, FileUtil,
{$ifdef TrndiExt}
Trndi.Ext.Engine, Trndi.Ext.Ext, trndi.Ext.jsfuncs,
{$endif}
LazFileUtils, uconf, trndi.native, Trndi.API, trndi.api.xDrip, StrUtils;

type
  // Procedures which are applied to the trend drawing
TTrendProc = procedure(l: TLabel; c, ix: integer) of object;
TTrendProcLoop = procedure(l: TLabel; c, ix: integer; ls: array of TLabel) of object;

  { TfBG }

TfBG = class(TForm)
  miRefresh:TMenuItem;
  miSplit4:TMenuItem;
  miLimitExplain: TMenuItem;
  miSplit3: TMenuItem;
  miRangeLo: TMenuItem;
  miRangeHi: TMenuItem;
  miSplit2: TMenuItem;
  miLO: TMenuItem;
  miHi: TMenuItem;
  miInfo: TMenuItem;
  miSplit1: TMenuItem;
  miForce: TMenuItem;
  pnOffRange: TPanel;
  lArrow: TLabel;
  lDiff: TLabel;
  lDot1: TLabel;
  lDot10: TLabel;
  lDot2: TLabel;
  lDot3: TLabel;
  lDot4: TLabel;
  lDot5: TLabel;
  lDot6: TLabel;
  lDot7: TLabel;
  lDot8: TLabel;
  lDot9: TLabel;
  lVal: TLabel;
  miSettings: TMenuItem;
  pmSettings: TPopupMenu;
  tMissed:TTimer;
  tTouch: TTimer;
  tMain: TTimer;
  procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
  procedure FormCreate(Sender: TObject);
  procedure FormResize(Sender: TObject);
  procedure lDiffDblClick(Sender: TObject);
  procedure lgMainClick(Sender: TObject);
  procedure lValClick(Sender: TObject);
  procedure lValMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
  procedure lValMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
  procedure lValStartDrag(Sender: TObject; var DragObject: TDragObject);
  procedure miForceClick(Sender: TObject);
  procedure miLimitExplainClick(Sender: TObject);
  procedure miSettingsClick(Sender: TObject);
  procedure onTrendClick(Sender: TObject);
  procedure pnOffRangeClick(Sender: TObject);
  procedure tMainTimer(Sender: TObject);
  procedure tMissedTimer(Sender:TObject);
  procedure tTouchTimer(Sender: TObject);
private
    // Array to hold references to lDot1 - lDot10
  TrendDots: array[1..10] of TLabel;

  procedure update;
  procedure PlaceTrendDots(const Readings: array of BGReading);
  procedure actOnTrend(proc: TTrendProc);
  procedure actOnTrend(proc: TTrendProcLoop);
  procedure setDotWidth(l: TLabel; c, ix: integer; ls: array of TLabel);
  procedure HideDot(l: TLabel; c, ix: integer);
  procedure ResizeDot(l: TLabel; c, ix: integer);
  procedure ExpandDot(l: TLabel; c, ix: integer);
  {$ifdef TrndiExt}
  procedure LoadExtensions;
  {$endif}
public

end;

procedure SetPointHeight(L: TLabel; value: single);

const
INTERVAL_MINUTES = 5; // Each time interval is 5 minutes
NUM_DOTS = 10;        // Total number of labels (lDot1 - lDot10)
DATA_FRESHNESS_THRESHOLD_MINUTES = 7; // Max minutes before data is considered outdated

BG_API_MIN = 2;
  // NS can't read lower
BG_API_MAX = 22;
  // NS can't read higher

var
lastup: tdatetime;
  // Colors (b)lood(g)lucose (c)olor XX
  // In range
bg_color_ok: TColor = $0000DC84;
bg_color_ok_txt: TColor = $00F2FFF2;
  // Hi
bg_color_hi: TColor = $0007DAFF;
bg_color_hi_txt: TColor = $000052FB;
  // Low
bg_color_lo: TColor = $00FFBE0B;
bg_color_lo_txt: TColor = $00FFFEE9;

  // Personal hi
bg_rel_color_lo: TColor = $00A859EE;
bg_rel_color_lo_txt: TColor = $002D074E;
  // Personal low
bg_rel_color_hi: TColor = $0072C9DE;
bg_rel_color_hi_txt: TColor = $001C6577;

fBG: TfBG;
api: TrndiAPI;
un: BGUnit = BGUnit.mmol;
bgs: BGResults;
{$ifdef TrndiExt}
jsFuncs: TJSfuncs;
{$endif}

  // Touch screen
StartTouch: TDateTime;
IsTouched: boolean;

privacyMode: boolean = false;

implementation

{$R *.lfm}
{$I tfuncs.inc}

procedure LogMessage(const Msg: string);
var
  LogFile: TextFile;
begin
  AssignFile(LogFile, 'trndi.log');
  if FileExists('trndi.log') then
    Append(LogFile)
  else
    Rewrite(LogFile);
  Writeln(LogFile, DateTimeToStr(Now) + ': ' + Msg);
  CloseFile(LogFile);
end;

{$ifdef TrndiExt}
// Load extension files
procedure TfBG.LoadExtensions;

var
  exts: TStringList;
  s, extdir: string;
begin
  TTrndiExtEngine.Instance;
  // Creates the class, if it's not already
  jsFuncs := TJSfuncs.Create(api);
  // This is an Object, not a class!
  extdir := GetAppConfigDirUTF8(false, true) + 'extensions' + DirectorySeparator;
  // Find extensions folder

  ForceDirectoriesUTF8(extdir);
  // Create the directory if it doesn't exist
  exts := FindAllFiles(extdir, '*.js', false);
  // Find .js files

  with TTrndiExtEngine.Instance do
  begin
    addClassFunction('uxProp', ExtFunction(@JSUX), 3);
    addClassFunction('getUnit', ExtFunction(@JSUnit), 0);
    addClassFunction('setLevelColor', ExtFunction(@JSLevelColor), -1);
    // Add the UX modification function, as declared in this file
    for s in exts do
      // Run all found files
      ExecuteFile(s);
    exts.Free;
  end;
end;
{$endif}

// Implement a simple insertion sort for BGReading
procedure SortReadingsDescending(var Readings: array of BGReading);
var
  i, j: integer;
  temp: BGReading;
begin
  for i := 1 to High(Readings) do
  begin
    temp := Readings[i];
    j := i - 1;
    while (j >= 0) and (Readings[j].date < temp.date) do
    begin
      Readings[j + 1] := Readings[j];
      Dec(j);
    end;
    Readings[j + 1] := temp;
  end;
end;

// Apply a procedure to all trend points; also provides an index
procedure TfBG.actOnTrend(proc: TTrendProcLoop);
var
  ix: integer;
  ls: array[1..10] of TLabel;
begin
  ls := TrendDots; // Directly use the TrendDots array
  for ix := 1 to NUM_DOTS do
    proc(ls[ix], NUM_DOTS, ix, ls);
  // Run the procedure on the given label
end;

// Apply a procedure to all trend points
procedure TfBG.actOnTrend(proc: TTrendProc);
var
  ix: integer;
  ls: array[1..10] of TLabel;
begin
  ls := TrendDots; // Directly use the TrendDots array
  for ix := 1 to NUM_DOTS do
    proc(ls[ix], NUM_DOTS, ix);
end;

// Initialize the TrendDots array in FormCreate
procedure TfBG.FormCreate(Sender: TObject);
var
  i: integer;
  s, apiTarget, apiCreds: string;
{$ifdef Linux}
function GetLinuxDistro: string;
  const
    Issue = '/etc/os-release';
  begin
    if FileExists(Issue) then
      Result := ReadFileToString(Issue)
    else
      Result := '';
  end;
  {$endif}
begin
  {$ifdef Linux}
  s := GetLinuxDistro;
  if (Pos('ID=fedora', s) > -1) then
    s := 'Poppins'
  else
  if (Pos('ID=ubuntu', s) > -1) then
    s := 'Ubuntu'
  else
    s := 'default';
  fBG.Font.Name := s;
  {$endif}
  // Assign labels to the TrendDots array
  for i := 1 to NUM_DOTS do
  begin
    s := 'lDot' + IntToStr(i);
    TrendDots[i] := FindComponent(s) as TLabel;
    if not Assigned(TrendDots[i]) then
      ShowMessage(Format('Label %s is missing!', [s]))
    else
      LogMessage(Format('Label %s assigned to TrendDots[%d].', [s, i]));
  end;

  with TrndiNative.Create do
  begin
    privacyMode := GetSetting('ext.privacy', '0') = '1';
    if GetSetting('unit', 'mmol') = 'mmol' then
      un := BGUnit.mmol
    else
      un := BGUnit.mgdl;
    apiTarget := GetSetting('remote.target');
    apiCreds := GetSetting('remote.creds');

    case GetSetting('remote.type') of
    'NightScout':
      api := NightScout.Create(apiTarget, apiCreds, '');
    'Dexcom (USA)':
      api := Dexcom.Create(apiTarget, apiCreds, 'usa');
    'Dexcom (Outside USA)':
      api := Dexcom.Create(apiTarget, apiCreds, 'world');
    'xDrip':
      api := xDrip.Create(apiTarget, apiCreds, '');
    else
      Exit;
    end;
  end;

  if not api.Connect then
  begin
    ShowMessage(api.ErrorMsg);
    Exit;
  end;

  {$ifdef TrndiExt}
  LoadExtensions;
  {$endif}

  update;
end;

// FormClose event handler
procedure TfBG.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  {$ifdef TrndiExt}
  TTrndiExtEngine.ReleaseInstance;
  {$endif}
end;

// Changes a trend dot from a dot to the actual bg value with highlighting for the latest reading
procedure TfBG.ExpandDot(l: TLabel; c, ix: integer);
begin
  if ix = NUM_DOTS then // Latest reading at lDot10
  begin
    if l.Caption = '•' then
    begin
      l.Caption := '☉'; // Use a triangle or another distinct symbol
      l.Font.Style := [fsBold];
      l.Font.Size := l.Font.Size + 2; // Increase font size for emphasis
    end
    else
    begin
      l.Caption := '•';
      l.Font.Style := [];
      l.Font.Size := Max(lVal.Font.Size div 8, 28);
    end;
  end
  else
  if (l.Caption = '•') and (not privacyMode) then
    l.Caption := '•'#10+l.Hint
  else
    l.Caption := '•';
end;

// Hides a dot
procedure TfBG.HideDot(l: TLabel; c, ix: integer);
begin
  l.Visible := false;
end;

// Scales a dot's font size
procedure TfBG.ResizeDot(l: TLabel; c, ix: integer);
begin
  l.AutoSize := true;
  l.Font.Size := Max(lVal.Font.Size div 8, 28); // Ensure minimum font size
  LogMessage(Format('TrendDots[%d] resized with Font Size = %d.', [ix, l.Font.Size]));
end;

// Sets the width (NOT the font) of a dot
procedure TfBG.SetDotWidth(l: TLabel; c, ix: integer; ls: array of TLabel);
var
  spacing: integer;
begin
  // Calculate spacing based on label width to prevent overlap
  spacing := (fBG.Width - (c * l.Width)) div (c + 1);

  // Position each label with equal spacing from the left
  l.Left := spacing + (spacing + l.Width) * (ix - 1);
  LogMessage(Format('TrendDots[%d] positioned at Left = %d.', [ix, l.Left]));
end;

// FormResize event handler
procedure TfBG.FormResize(Sender: TObject);
procedure scaleLbl(ALabel: TLabel);
  var
    MaxWidth, MaxHeight: integer;
    TestSize, MaxFontSize: integer;
    TextWidth, TextHeight: integer;
  begin
    // Set the maximum feasible font size
    MaxFontSize := 150;

    // Set the maximum feasible width and height
    MaxWidth := ALabel.Width;
    MaxHeight := ALabel.Height;

    // Check if the font will fit
    for TestSize := 1 to MaxFontSize do
    begin
      ALabel.Font.Size := TestSize;
      TextWidth := ALabel.Canvas.TextWidth(ALabel.Caption);
      TextHeight := ALabel.Canvas.TextHeight(ALabel.Caption);

      // Exit if the font won't fit
      if (TextWidth > MaxWidth) or (TextHeight > MaxHeight) then
      begin
        ALabel.Font.Size := TestSize - 1;
        Exit;
      end;
    end;

    // If we never exited, set the max feasible size
    ALabel.Font.Size := MaxFontSize;
  end;

var
  i: integer;
begin
  // Update dot placement
  actOnTrend(@SetDotWidth);

  // Remove or comment out the following line to prevent labels from being hidden:
  // actOnTrend(@HideDot);

  // Adjust label sizes
//  lArrow.Height := fBG.clientHeight div 3;
  scaleLbl(lVal);
  scaleLbl(lArrow);
  lDiff.Width := ClientWidth;
  lDiff.Height := lVal.Height div 7;
  scaleLbl(lDiff);

  // Resize the dots
  actOnTrend(@ResizeDot);

  // Set info
  miHi.Caption := Format('Hi > %.1f', [api.cgmHi * BG_CONVERTIONS[un][mgdl]]);
  miLo.Caption := Format('Lo < %.1f', [api.cgmLo * BG_CONVERTIONS[un][mgdl]]);
  if api.cgmRangeHi <> 500 then
    miRangeHi.Caption := Format('Range Hi > %.1f', [api.cgmRangeHi * BG_CONVERTIONS[un][mgdl]])
  else
    miRangeHi.Caption := 'Hi range not supported by API';

  if api.cgmRangeLo <> 0 then
    miRangeLo.Caption := Format('Range Lo < %.1f', [api.cgmRangeLo * BG_CONVERTIONS[un][mgdl]])
  else
    miRangeLo.Caption := 'LO range not supported by API';


  pnOffRange.width := clientwidth div 4;
  pnOffRange.height := clientheight div 10;
  pnOffRange.left := 0;
  pnOffRange.top := 0;
  pnOffRange.Font.Size := 7 + pnOffRange.Height div 5;


  PlaceTrendDots(bgs); // Crashes
end;

// Handle full screen toggle on double-click
procedure TfBG.lDiffDblClick(Sender: TObject);
begin
  if fBG.WindowState = wsMaximized then
  begin
    fBG.WindowState := wsNormal;
    fBG.FormStyle := fsNormal;
    fBG.BorderStyle := bsSizeable;
  end
  else
  begin
    fBG.WindowState := wsMaximized;
    fBG.FormStyle := fsStayOnTop;
    fBG.BorderStyle := bsNone;
  end;
end;

// Empty event handler
procedure TfBG.lgMainClick(Sender: TObject);
begin
  // Event handler can be left empty if not used
end;

// Handle lVal click
procedure TfBG.lValClick(Sender: TObject);
begin
  if lVal.Caption = 'Setup' then
    miSettings.Click;
end;

// Handle mouse down on lVal
procedure TfBG.lValMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  // Handle touch screens
  StartTouch := Now;
  IsTouched := true;
  tTouch.Enabled := true;
end;

// Handle mouse up on lVal
procedure TfBG.lValMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  IsTouched := false;
  tTouch.Enabled := false;
end;

// Empty drag event handler
procedure TfBG.lValStartDrag(Sender: TObject; var DragObject: TDragObject);
begin
  // Event handler can be left empty if not used
end;

// Force update on menu click
procedure TfBG.miForceClick(Sender: TObject);
begin
  update;
end;

// Explain limit menu click
procedure TfBG.miLimitExplainClick(Sender: TObject);
begin
  ShowMessage('Hi = When BG is considered high'#10 +
    'Lo = When BG is considered low'#10#10 +
    'Ranges: Defines "desirable" levels within normal. Not supported by all backends');
end;

// Handle settings menu click
procedure TfBG.miSettingsClick(Sender: TObject);
var
  i: integer;
  s: string;
begin
  with TfConf.Create(self) do
    with TrndiNative.Create do
    begin
      s := GetSetting('remote.type');
      for i := 0 to cbSys.Items.Count - 1 do
        if cbSys.Items[i] = s then
          cbSys.ItemIndex := i;

      eAddr.Text := GetSetting('remote.target');
      ePass.Text := GetSetting('remote.creds');
      rbUnit.ItemIndex := IfThen(GetSetting('unit', 'mmol') = 'mmol', 0, 1);
      {$ifdef TrndiExt}
      eExt.Text := GetAppConfigDirUTF8(false, true) + 'extensions' + DirectorySeparator;
      {$else}
      eExt.Text := '- Built Without Support -';
      eExt.Enabled := false;
      {$endif}
      cbPrivacy.Checked := GetSetting('ext.privacy', '0') = '1';
      ShowModal;
      SetSetting('remote.type', cbSys.Text);
      SetSetting('remote.target', eAddr.Text);
      SetSetting('remote.creds', ePass.Text);
      SetSetting('unit', IfThen(rbUnit.ItemIndex = 0, 'mmol', 'mgdl'));
      SetSetting('ext.privacy', IfThen(cbPrivacy.Checked, '1', '0'));
    end;
end;

// Swap dots with their readings
procedure TfBG.onTrendClick(Sender: TObject);
begin
  actOnTrend(@ExpandDot);
end;

// Handle off range panel click
procedure TfBG.pnOffRangeClick(Sender: TObject);
begin
  ShowMessage('In addition to high and low levels, you have set a personal range within "OK". You are now ' +
    IfThen((Sender as TPanel).Color = bg_rel_color_hi, 'over', 'under') +
    ' that range');
end;

// Update remote on timer
procedure TfBG.tMainTimer(Sender: TObject);
var
  r: BGReading;
begin
  update;
  {$ifdef TrndiExt}
  TTrndiExtEngine.Instance.CallFunction('updateCallback', [bgs[Low(bgs)].val.ToString, DateTimeToStr(Now)]);
  {$endif}
end;

procedure TfBG.tMissedTimer(Sender:TObject);
var
  d, diff: TDateTime;
  min, sec: int64;
begin
    d := bgs[Low(bgs)].date; // Last reading time
    diff := Now-d;


    min := MilliSecondsBetween(Now, d) div 60000;
    sec := (MilliSecondsBetween(Now, d) mod 60000) div 1000;

    lDiff.Caption := Format('%s (%d.%.2d ago)', [FormatDateTime('H:mm', d), min, sec]);
end;

// Handle a touch screen's long touch
procedure TfBG.tTouchTimer(Sender: TObject);
var
  p: TPoint;
begin
  tTouch.Enabled := false;
  if IsTouched then
  begin
    p := Mouse.CursorPos;
    pmSettings.PopUp(p.X, p.Y);
  end;
end;

// Request data from the backend and update GUI
procedure TfBG.update;
var
  b: BGReading;
  i: int64;
begin
  lastup := 0;
  // Fetch current readings
  bgs := api.getReadings(10, 25);
  if Length(bgs) < 1 then
  begin
    ShowMessage('Cannot contact backend server');
    Exit;
  end;

  // Call the new method to place the points
  PlaceTrendDots(bgs);

  // Update other GUI elements based on the latest reading
  b := bgs[Low(bgs)];
  if not privacyMode then
    lVal.Caption := b.format(un, BG_MSG_SHORT, BGPrimary)
  else
    lVal.Caption := '';
  lDiff.Caption := b.format(un, BG_MSG_SIG_SHORT, BGDelta);
  lArrow.Caption := b.trend.Img;
  lVal.Font.Style := [];

  // Log latest reading
  LogMessage(Format('Latest Reading: Value = %.2f, Date = %s', [b.val, DateTimeToStr(b.date)]));

  // Set next update time
  tMain.Enabled := false;
  i := SecondsBetween(b.date, now); // Seconds from last
  i := min(300000,  // 5 min
    300000-(i*1000) // 5 minutes minus time from last check
    ); // Minimal 5 min to next check

  i := max(120000, i); // Don't allow too small refresh time. Now we have a time between 2-5 mins

  tMain.Interval := i;
  tMain.Enabled := true;
  miRefresh.Caption := Format('Refreshing at %s', [TimeToStr(IncMilliSecond(Now, i))]);

  // Check if the latest reading is fresh
  if MinutesBetween(Now, b.date) > DATA_FRESHNESS_THRESHOLD_MINUTES then
  begin
//    lDiff.Caption := TimeToStr(b.date) + ' (' + MinutesBetween(Now, b.date).ToString + ' min)';
    tMissed.OnTimer(tMissed);
    lVal.Font.Style := [fsStrikeOut];
    fBG.Color := clBlack;
    tMissed.Enabled := true;
    Exit;
  end;
  tMissed.Enabled := false;

  // Set background color based on the latest reading
  if b.val >= api.cgmHi then
    fBG.Color := bg_color_hi
  else
  if b.val <= api.cgmLo then
    fBG.Color := bg_color_lo
  else
  begin
    fBG.Color := bg_color_ok;
    // Check personalized limit

    if (b.val >= api.cgmHi) or (b.val <= api.cgmLo) then
      pnOffRange.Visible := false // block off elses
    else
    if b.val <= api.cgmRangeLo then
    begin
      pnOffRange.Color := bg_rel_color_lo;
      pnOffRange.Font.Color := bg_rel_color_lo_txt;
      pnOffRange.Visible := true;
    end
    else
    if b.val >= api.cgmRangeHi then
    begin
      pnOffRange.Color := bg_rel_color_hi;
      pnOffRange.Font.Color := bg_rel_color_hi_txt;
      pnOffRange.Visible := true;
    end
  end;
  lastup := Now;
if privacyMode then begin
  if fBG.Color = bg_color_hi then
       lVal.Caption := '⭱'
  else if fBG.Color =  bg_color_lo then
       lVal.Caption := '⭳'
    else
       lVal.Caption := '✓';
end;
 Self.OnResize(self);
end;

// PlaceTrendDots method to map readings to TrendDots
procedure TfBG.PlaceTrendDots(const Readings: array of BGReading);
var
  SortedReadings: array of BGReading;
  i, j: integer;
  temp: BGReading;
  slotIndex: integer;
  l: TLabel;
  slotStart, slotEnd: TDateTime;
  reading: BGReading;
  found: boolean;
  labelNumber: integer;
begin
  if Length(Readings) = 0 then
    Exit;

  // Copy Readings to SortedReadings
  SetLength(SortedReadings, Length(Readings));
  for i := 0 to High(Readings) do
    SortedReadings[i] := Readings[i];

  // Sort SortedReadings in descending order based on date (latest first)
  SortReadingsDescending(SortedReadings);

  // Check if the latest reading is fresh
  if (MinutesBetween(Now, SortedReadings[0].date) > DATA_FRESHNESS_THRESHOLD_MINUTES) then
  begin
    // Hide the last label if the latest reading is outdated
    if Assigned(TrendDots[10]) then
    begin
      TrendDots[10].Visible := false;
      LogMessage('TrendDots[10] hidden due to outdated reading.');
    end;
  end
  else
  if Assigned(TrendDots[10]) then
  begin
    TrendDots[10].Visible := true;
    LogMessage('TrendDots[10] shown as latest reading is fresh.');
  end// Ensure the last label is visible if the latest reading is fresh
  ;

  // Iterate through each time interval and corresponding label
  for slotIndex := 0 to NUM_DOTS - 1 do
  begin
    // Define the start and end time for the interval
    slotEnd := IncMinute(Now, -INTERVAL_MINUTES * slotIndex);
    slotStart := IncMinute(slotEnd, -INTERVAL_MINUTES);

    found := false;

    // Search through the readings to find the latest one that falls within the interval
    for i := 0 to High(SortedReadings) do
    begin
      reading := SortedReadings[i];
      if (reading.date <= slotEnd) and (reading.date > slotStart) then
      begin
        // Map slotIndex to label number (0 -> lDot10, 1 -> lDot9, ..., 9 -> lDot1)
        labelNumber := NUM_DOTS - slotIndex;
        l := TrendDots[labelNumber];

        if Assigned(l) then
        begin
          // Update label properties based on the reading
          l.Visible := true;
          l.Hint := reading.format(un, BG_MSG_SHORT, BGPrimary);
          l.Caption := '•'; // Or another symbol
          setPointHeight(l, reading.convert(mmol));

          // Set colors based on the value
          if reading.val >= api.cgmHi then
            l.Font.Color := bg_color_hi_txt
          else
          if reading.val <= api.cgmLo then
            l.Font.Color := bg_color_lo_txt
          else
          begin
            l.Font.Color := bg_color_ok_txt;
            if reading.val <= api.cgmRangeLo then
              l.Font.Color := bg_rel_color_lo_txt
            else
            if reading.val >= api.cgmRangeHi then
              l.Font.Color := bg_rel_color_hi_txt;
          end;

          LogMessage(Format('TrendDots[%d] updated with reading at %s (Value: %.2f).', [labelNumber, DateTimeToStr(reading.date), reading.val]));
        end;

        found := true;
        Break; // Move to the next time interval
      end;
    end;

    // If no reading was found within the interval, hide the label
    if not found then
    begin
      labelNumber := NUM_DOTS - slotIndex;
      l := TrendDots[labelNumber];
      if Assigned(l) then
      begin
        l.Visible := false;
        LogMessage(Format('TrendDots[%d] hidden as no reading found in interval.', [labelNumber]));
      end;
    end;
  end;

  // Adjust the layout after updating the labels
  // FormResize(Self); <-- we need to call this manually, or we get an infinite loop
end;

// SetPointHeight procedure
procedure SetPointHeight(L: TLabel; value: single);
var
  Padding, UsableHeight, Position: integer;
begin
  if (Value >= 2) and (Value <= 22) then
  begin
    Padding := Round(fBG.ClientHeight * 0.1);
    // 10% padding
    UsableHeight := fBG.ClientHeight - 2 * Padding;

    // Calculate placement, respecting padding
    Position := Padding + Round((Value - 2) / 20 * UsableHeight);

    // Clamp Position within usable range
    if Position < Padding then
      Position := Padding
    else
    if Position > (Padding + UsableHeight) then
      Position := Padding + UsableHeight;

    L.Top := fBG.ClientHeight - Position;
    // Optional: Log the vertical position if label index is available
  end
  else
    ShowMessage('Cannot draw graph points outside 2 and 22');
end;


end.
