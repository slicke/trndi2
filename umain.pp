
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
Classes,Menus,SysUtils,Forms,Controls,Graphics,Dialogs,StdCtrls,ExtCtrls,
dexapi, nsapi, trndi.types,math,DateUtils,FileUtil,
  {$ifdef TrndiExt}Trndi.Ext.Engine,Trndi.Ext.Ext, trndi.Ext.jsfuncs,{$endif}
LazFileUtils, uconf, trndi.native, Trndi.API, trndi.api.xDrip, StrUtils;

type 

  // Procedures which are applied to the trend drawing
  TTrendProc = procedure (l: TLabel; c, ix: integer) of object;
  TTrendProcLoop = procedure (l: TLabel; c, ix: integer; ls: array of TLabel) of object;


  { TfBG }

  TfBG = class(TForm)
      miLimitExplain:TMenuItem;
      miSplit3:TMenuItem;
      miRangeLo:TMenuItem;
      miRangeHi:TMenuItem;
      miSplit2:TMenuItem;
      miLO:TMenuItem;
      miHi:TMenuItem;
      miInfo:TMenuItem;
      miSplit1:TMenuItem;
      miForce:TMenuItem;
      pnOffRange:TPanel;
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
    tTouch: TTimer;
    tMain: TTimer;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender:TObject);
    procedure FormResize(Sender: TObject);
    procedure lDiffDblClick(Sender: TObject);
    procedure lgMainClick(Sender: TObject);
    procedure lValClick(Sender:TObject);
    procedure lValMouseDown(Sender:TObject;Button:TMouseButton;Shift:TShiftState
                            ;X,Y:Integer);
    procedure lValMouseUp(Sender:TObject;Button:TMouseButton;Shift:TShiftState;X
                          ,Y:Integer);
    procedure lValStartDrag(Sender: TObject; var DragObject: TDragObject);
    procedure miForceClick(Sender:TObject);
    procedure miLimitExplainClick(Sender:TObject);
    procedure miSettingsClick(Sender:TObject);
    procedure onTrendClick(Sender: TObject);
    procedure pnOffRangeClick(Sender:TObject);
    procedure tMainTimer(Sender: TObject);
    procedure tTouchTimer(Sender:TObject);
    private 
      procedure update;
      procedure actOnTrend(proc: TTrendProc);
      procedure actOnTrend(proc: TTrendProcLoop);
      procedure setDotWidth(l: TLabel; c, ix: integer; ls: array of TLabel);
      procedure HideDot(l: TLabel; c, ix: integer);
      procedure ResizeDot(l: TLabel; c, ix: integer);
      procedure ExpandDot(l: TLabel; c, ix: integer);
      {$ifdef TrndiExt}
      procedure LoadExtensions; {$endif}
    public 

  end;

const 
  bgmin = 2;
  // NS cant read lower
  bgmax = 22;
  // NS can't read higher
  // Colors (b)lood(g)lucose (c)olor XX
  // In range
  bgcok = $0000DC84;
  bgcoktxt = $00F2FFF2;
  // Hi
  bgchi = $0007DAFF;
  bgchitxt = $00F3FEFF;
  // Low
  bgclo = $00FFBE0B;
  bgclotxt = $00FFFEE9;


  // Personal hi
  bgcrlo = $00A859EE;
  bgcrlotxt = $002D074E;
  // Personal low
  bgcrhi = $0072C9DE;
  bgcrhitxt = $001C6577;
var 
  fBG: TfBG;
  api: TrndiAPI;
  un: BGUnit = BGUnit.mmol;
  bgs: BGResults;
  {$ifdef TrndiExt}
  jsFuncs:  TJSfuncs;
  {$endif}

  // Touch screen
  StartTouch: TDateTime;
  IsTouched: Boolean;

implementation

{$R *.lfm}
{$I tfuncs.inc}


{$ifdef TrndiExt}
// Load extension files
procedure TfBG.LoadExtensions;

var 
  exts : TStringList;
  s, extdir: string;
begin
  TTrndiExtEngine.Instance;
  // Creates the class, if it's not already
  jsFuncs := TJSfuncs.Create(api);
  // This is an Object, not a class!
  extdir := GetAppConfigDirUTF8(false, true) + 'extensions' + DirectorySeparator;
  // Find extensions folder

  ForceDirectoriesUTF8(extdir);
  // We create the dir if it doesn't exist
  exts := FindAllFiles(extdir, '*.js', false);
  // Find .js

  with TTrndiExtEngine.Instance do
    begin
      addFunction('uxProp', ExtFunction(@JSUX), 3);
      // Add the UX modification function, as we declre it in this file
      for s in exts do
        // Run all found files
        ExecuteFile(s);
      exts.Free;
    end;
end;

{$endif}

// Apply a function to all trend points; also provides an index
procedure TfBG.actOnTrend(proc: TTrendProcLoop);

var 
  ix, lx: integer;
  ls: array of TLabel;
begin
  ls := [lDot1,lDot2,lDot3,lDot4,lDot5,lDot6,lDot7,lDot8,lDot9,lDot10];
  // All dots that make up the graph
  lx := length(ls);
  for ix:= 0 to length(ls)-1 do
    proc(ls[ix], lx, ix, ls);
  // Run the method on the given label
end;

// Apply a function to all trend points
procedure TfBG.actOnTrend(proc: TTrendProc);

var 
  ix, lx: integer;
  ls: array of TLabel;
begin
  ls := [lDot1,lDot2,lDot3,lDot4,lDot5,lDot6,lDot7,lDot8,lDot9,lDot10];
  lx := length(ls);
  for ix:= 0 to length(ls)-1 do
    proc(ls[ix], lx, ix);
end;

procedure TfBG.FormCreate(Sender:TObject);

var 
  s, apiTarget, apiCreds: string;
{$ifdef Linux}
function GetLinuxDistro: String;
const 
  Issue = '/etc/os-release';
begin
  case FileExists(Issue) of 
    True:  Result := ReadFileToString(Issue);
    False: Result := '';
  end;
end;

begin
  s := GetLinuxDistro;
  if (Pos('ID=fedora', s) > -1) then
    s := 'Poppins'
  else if (Pos('ID=ubuntu', s) > -1) then
         s := 'Ubuntu'
  else
    s := 'default';
  fBG.Font.Name := s;
  {$else}
  begin
  {$endif}
    with TrndiNative.create do
      begin
        if GetSetting('unit', 'mmol') = 'mmol' then
          un := BGUnit.mmol
        else
          un := BGUnit.mgdl;
        apiTarget := GetSetting('remote.target');
        apiCreds := GetSetting('remote.creds');

        case GetSetting('remote.type') of 
          'NightScout': api := NightScout.create(apiTarget, apiCreds, '');
          'Dexcom (USA)': api := Dexcom.create(apiTarget, apiCreds, 'usa');
          'Dexcom (Outside USA)': api := Dexcom.create(apiTarget, apiCreds, 'world');
          'xDrip': api := xDrip.create(apiTarget, apiCreds, '');
          else
            Exit;
        end;

      end;
    if not api.connect then
      begin
        ShowMessage(api.errormsg);
        exit;
      end;
    {$ifdef TrndiExt}
    LoadExtensions;
    {$endif}
    update;
  end;

  procedure TfBG.FormClose(Sender: TObject; var CloseAction: TCloseAction);
  begin
     {$ifdef TrndiExt}
    TTrndiExtEngine.ReleaseInstance;
    {$endif}
  end;

  // Changes a trend dot from a dot to the actual bg value
  procedure TfBG.ExpandDot(l: TLabel; c, ix: integer);
  begin
    if l.Caption = '•' then
      l.Caption := l.Hint
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
    l.font.Size := lVal.Font.Size div 8;

  end;

  // Sets the width (NOT the font) of a dot
  procedure TfBG.SetDotWidth(l: TLabel; c, ix: integer; ls: array of TLabel);

  var 
    i: integer;
  begin
    i := fBG.Width div c;

    if ix > 0 then
      l.left := ls[ix-1].left + i
    else
      l.left := i div 2;
  end;

  procedure TfBG.FormResize(Sender: TObject);
  procedure scaleLbl(ALabel: TLabel);

  var 
    MaxWidth, MaxHeight: Integer;
    TestSize, MaxFontSize: Integer;
    TextWidth, TextHeight: Integer;
  begin
    // Set the maximum fesible font size
    MaxFontSize := 150;

    // Set the maximum fesible width
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

    // If we never existed, set the max fesible size
    ALabel.Font.Size := MaxFontSize;
  end;

  procedure SetHeight(L: TLabel; value: single);

  var 
    Padding, UsableHeight, Position: Integer;
  begin
    if (Value >= 2) and (Value <= 22) then
      begin
        Padding := Round(fBG.ClientHeight * 0.1);
        // 10% padding
        UsableHeight := fBG.ClientHeight - 2 * Padding;

        // Calculate placement, respecting padding
        Position := Padding + Round((Value - 2) / 20 * UsableHeight);

        L.Top := fBG.ClientHeight - Position;
      end
    else
      ShowMessage('Cannot draw graph points outside 2 and 22');
  end;


  var 
    l: TLabel;
    pos, i, x: integer;
    b: BGReading;
    r: single;
  begin

    // Update the dot space and hide them during update
    actOnTrend(@SetDotWidth);
    actOnTrend(@HideDot);

    // Calculate the area we can use
    pos := (bgmax - bgmin) * lDot1.Parent.ClientHeight;

    // Positin the dots, the amount of dots is hard coded
    for i:= Low(bgs) to min(9, high(bgs)) do
      begin
        // bgs = readings we have
        b := bgs[i];
        l := fBG.FindChildControl('lDot'+(10-i).ToString) as TLabel;

        r := b.convert(mmol);

        // Hide the dot if it's out of range
        if r > bgmax then
          l.Visible := false
        else if r < bgmin then
               l.Visible := false
        else
          begin
            l.visible := true;
            setHeight(l, r);
          end;

        // Set the hint of the dot to the reading
        l.Hint := b.format(un, BG_MSG_SHORT , BGPrimary);;

pnOffRange.Height := ClientHeight div 25;
        if b.val >= api.cgmHi then
          l.Font.color := bgchitxt
        else if b.val <= api.cgmLo then
          l.Font.color := bgclotxt
        else begin
           l.Font.color := bgcoktxt;

          if b.val <= api.cgmRangeLo then
             l.font.Color := bgcrlotxt
          else if b.val >= api.cgmRangeHi then
             l.font.Color := bgcrhi;
          end;
        end;


    // Adjust the arrow and label sizes
    lArrow.Height := lVal.Height div 5;
    scaleLbl(lVal);
    scaleLbl(lArrow);
    lDiff.Width := ClientWidth;;
    lDiff.Height := lval.Height div 7;
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

    if api.cgmRangeLo  <> 0 then
      miRangeLo.Caption := Format('Range Lo < %.1f', [api.cgmRangeLo * BG_CONVERTIONS[un][mgdl]])
    else
      miRangeLo.Caption := 'LO range not supported by API';
  end;

  // Handle full screen
  procedure TfBG.lDiffDblClick(Sender: TObject);
  begin
    if fBG.WindowState = wsMaximized then
      begin
        fBG.WindowState := wsNormal;
        fBG.FormStyle   := fsNormal;
        fBG.BorderStyle := bsSizeable;
      end
    else
      begin
        fBG.WindowState := wsMaximized;
        fBG.FormStyle   := fsStayOnTop;
        fBG.BorderStyle := bsNone;
      end;

  end;

  procedure TfBG.lgMainClick(Sender: TObject);
  begin

  end;

  procedure TfBG.lValClick(Sender:TObject);
  begin
    if lVal.Caption = 'Setup' then
      miSettings.Click;
  end;

  procedure TfBG.lValMouseDown(Sender:TObject;Button:TMouseButton;Shift:
                               TShiftState;X,Y:Integer);
  begin
    // Handle touch screens
    StartTouch := Now;
    IsTouched := True;
    tTouch.Enabled := True;
  end;

  procedure TfBG.lValMouseUp(Sender:TObject;Button:TMouseButton;Shift:TShiftState;
                             X,Y:Integer);
  begin
    IsTouched := False;
    tTouch.Enabled := False;
  end;

  procedure TfBG.lValStartDrag(Sender: TObject; var DragObject: TDragObject);
  begin

  end;

procedure TfBG.miForceClick(Sender:TObject);
begin
  update;
end;

procedure TfBG.miLimitExplainClick(Sender:TObject);
begin
ShowMessage('Hi = When BG is considered high'#10'Lo = When BG is considered low'#10#10'Ranges: Defines "desirable" levels within normal. Not supported by all backends')
end;

  procedure TfBG.miSettingsClick(Sender:TObject);

  var 
    i : integer;
    s: string;
  begin
    with TfConf.Create(self) do
      begin

        with TrndiNative.create do
          begin
            s := GetSetting('remote.type');
            for i := 0 to cbSys.items.Count-1 do
              if  cbSys.Items[i] = s then
                cbSys.ItemIndex := i;

            eAddr.text := GetSetting('remote.target');
            ePass.Text := GetSetting('remote.creds');
            rbUnit.ItemIndex := IfThen(GetSetting('unit', 'mmol') = 'mmol', 0, 1);
            {$ifdef TrndiExt}
            eExt.Text := GetAppConfigDirUTF8(false, true) + 'extensions' + DirectorySeparator;
            {$else}
            eExt.Text := '- Built Wihout Support -';
            eExt.Enabled := false;
            {$endif}
            ShowModal;
            SetSetting('remote.type', cbSys.Text);
            SetSetting('remote.target', eAddr.text);
            SetSetting('remote.creds', ePass.Text);
            SetSetting('unit', IfThen(rbUnit.ItemIndex = 0, 'mmol', 'mgdl'));
          end;
      end;
  end;


  // Swap dots with their readings
  procedure TfBG.onTrendClick(Sender: TObject);
  begin
    actOnTrend(@ExpandDot);
  end;

procedure TfBG.pnOffRangeClick(Sender:TObject);
begin
ShowMessage('In addition to high and low levels, you have set a personal range within "OK". You are now ' + IfThen((sender as TPanel).Color = bgchi, 'over', 'under') + ' that range');
end;

  // Update remote on timer
  procedure TfBG.tMainTimer(Sender: TObject);
  begin
    update;
    // @todo call JS
  end;

  // Handle a touch screen's long touch
  procedure TfBG.tTouchTimer(Sender:TObject);

  var 
    p: TPoint;
  begin
    tTouch.Enabled := False;
    if IsTouched then
      begin
        p := Mouse.CursorPos;
        pmSettings.PopUp(p.X, p.Y);
      end;
  end;

  // Request data from the backend and update gui
  procedure TfBG.update;

  var 
    i: integer;
    l: TLabel;
    b: BGReading;
  begin
    // get 10 - 25 readings (depends on the backend if the max is used)
    bgs := api.getReadings(10,25);
    if length(bgs) < 1 then
      begin
        Showmessage('Cannot contact backend server');
        Exit;
      end;
    // Get the most recent reading
    b := bgs[low(bgs)];
    // Format the labels
    lVal.Caption := b.format(un, BG_MSG_SHORT , BGPrimary);
    lDiff.Caption := b.format(un, BG_MSG_SIG_SHORT, BGDelta);
    lArrow.Caption := b.trend.Img;
    lVal.Font.Style := [];

    // Determine if the reading if fresh
    if MinutesBetween(Now, b.date) > 7 then
      begin
        lDiff.Caption := TimeToStr(b.date) + ' (' + MinutesBetween(Now, b.date).ToString + ' min)';
        lVal.Font.Style := [fsStrikeOut];
        fBG.Color := clBlack;
        Exit;
      end;

        if b.val >= api.cgmHi then
          fBG.color := bgchi
        else if b.val <= api.cgmLo then
          fBG.color := bgclo
        else begin
           fBG.color := bgcok;
           // Check the levelbar
          pnOffRange.Visible := true;
          pnOffRange.Color := clBlue;
          pnOffRange.Height := ClientHeight div 25;

          if b.val <= api.cgmRangeLo then
             begin pnOffRange.Color := bgcrlo; pnOffRange.font.color := bgcrlotxt; end
          else if b.val >= api.cgmRangeHi then
             begin pnOffRange.Color := bgcrhi; pnOffRange.font.color := bgcrhitxt; end
          else
            pnOffRange.Visible := false;
        end;


  end;

end.
