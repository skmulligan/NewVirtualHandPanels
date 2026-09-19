unit PanelSurfaceControl;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Classes,
  System.Types,
  Vcl.Controls,
  Vcl.Graphics;

type
  TPanelSurfaceInvokeEvent = procedure(Sender: TObject; Direction: Integer) of object;

  { A keyboard-focusable hit area that paints its exact portion of the panel
    artwork. No native button face is drawn over the original graphic. }
  TPanelSurfaceControl = class(TCustomControl)
  private
    FArtwork: TPicture;
    FDesignBounds: TRect;
    FSplit: Boolean;
    FAvailable: Boolean;
    FSelected: Boolean;
    FHotSide: Integer;
    FPressedSide: Integer;
    FKeyboardKey: Word;
    FPositiveCommand: Integer;
    FOnInvoke: TPanelSurfaceInvokeEvent;
    function HitSide(X, Y: Integer): Integer;
    procedure CancelPress;
    procedure SetSelected(Value: Boolean);
    procedure SetAvailable(Value: Boolean);
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
    procedure CMEnabledChanged(var Message: TMessage); message CM_ENABLEDCHANGED;
    procedure WMKillFocus(var Message: TWMKillFocus); message WM_KILLFOCUS;
    procedure WMSetFocus(var Message: TWMSetFocus); message WM_SETFOCUS;
    procedure WMGetDlgCode(var Message: TWMGetDlgCode); message WM_GETDLGCODE;
    procedure WMKeyDown(var Message: TWMKey); message WM_KEYDOWN;
    procedure WMCancelMode(var Message: TMessage); message WM_CANCELMODE;
    procedure WMCaptureChanged(var Message: TMessage); message WM_CAPTURECHANGED;
  protected
    procedure Paint; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState;
      X, Y: Integer); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure KeyUp(var Key: Word; Shift: TShiftState); override;
  public
    constructor Create(AOwner: TComponent); override;
    property Caption;
    property Artwork: TPicture read FArtwork write FArtwork;
    property DesignBounds: TRect read FDesignBounds write FDesignBounds;
    property Split: Boolean read FSplit write FSplit;
    property Available: Boolean read FAvailable write SetAvailable;
    property Selected: Boolean read FSelected write SetSelected;
    property PositiveCommand: Integer read FPositiveCommand write FPositiveCommand;
    property OnInvoke: TPanelSurfaceInvokeEvent read FOnInvoke write FOnInvoke;
  end;

implementation

uses
  System.Math;

constructor TPanelSurfaceControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := (ControlStyle + [csOpaque]) -
    [csClickEvents, csDoubleClicks, csCaptureMouse];
  DoubleBuffered := True;
  TabStop := True;
  FAvailable := True;
  Cursor := crHandPoint;
  ShowHint := True;
end;

function TPanelSurfaceControl.HitSide(X, Y: Integer): Integer;
var
  NX, NY: Double;
begin
  Result := 0;
  if not Enabled or not FAvailable or (Width <= 0) or (Height <= 0) then
    Exit;
  NX := (2.0 * X - Width) / Width;
  NY := (2.0 * Y - Height) / Height;
  if Sqr(NX) + Sqr(NY) > 1 then
    Exit;
  if FSplit and (X < Width div 2) then
    Result := -1
  else
    Result := 1;
end;

procedure TPanelSurfaceControl.Paint;
var
  Ring: TRect;
  TextBounds: TRect;
  SavedDC: Integer;
  Side: Integer;
  Stroke: Integer;
  Mark: string;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := clWhite;
  Canvas.FillRect(ClientRect);
  if (FArtwork <> nil) and (FArtwork.Graphic <> nil) and (Parent <> nil) then
    Canvas.StretchDraw(Rect(-Left, -Top, Parent.ClientWidth - Left,
      Parent.ClientHeight - Top), FArtwork.Graphic);

  Stroke := Max(1, Round(Width / 28));
  Ring := Rect(Stroke + 1, Stroke + 1, Width - Stroke - 1, Height - Stroke - 1);
  Canvas.Brush.Style := bsClear;
  Canvas.Pen.Width := Stroke;

  if not FAvailable then
  begin
    { Leave the physical location visible while marking it unavailable. }
    Canvas.Pen.Color := RGB(124, 125, 114);
    Canvas.MoveTo(Width div 3, Height * 2 div 3);
    Canvas.LineTo(Width * 2 div 3, Height div 3);
    Exit;
  end;

  if FSelected and Enabled then
  begin
    Canvas.Pen.Color := RGB(70, 105, 54);
    Canvas.Ellipse(Ring.Left, Ring.Top, Ring.Right, Ring.Bottom);
  end;
  if Enabled and ((FHotSide <> 0) or Focused or (FPressedSide <> 0)) then
  begin
    if FPressedSide <> 0 then
      Canvas.Pen.Color := RGB(69, 97, 48)
    else
      Canvas.Pen.Color := RGB(228, 238, 199);
    SavedDC := SaveDC(Canvas.Handle);
    try
      { Highlight only the active half of a knob; do not hide its texture. }
      if FSplit and not Focused then
      begin
        if FHotSide < 0 then
          IntersectClipRect(Canvas.Handle, 0, 0, Width div 2, Height)
        else if FHotSide > 0 then
          IntersectClipRect(Canvas.Handle, Width div 2, 0, Width, Height);
      end;
      Canvas.Ellipse(Ring.Left, Ring.Top, Ring.Right, Ring.Bottom);
    finally
      RestoreDC(Canvas.Handle, SavedDC);
    end;
    if FPressedSide <> 0 then
    begin
      InflateRect(Ring, -Stroke - 1, -Stroke - 1);
      Canvas.Ellipse(Ring.Left, Ring.Top, Ring.Right, Ring.Bottom);
    end;
  end;

  if FSplit then
  begin
    Canvas.Font.Name := 'Segoe UI';
    Canvas.Font.Height := -Max(12, Round(Height * 0.34));
    if Enabled then
      Canvas.Font.Color := RGB(66, 72, 58)
    else
      Canvas.Font.Color := RGB(145, 146, 135);
    SetBkMode(Canvas.Handle, TRANSPARENT);
    for Side := -1 to 1 do
      if Side <> 0 then
      begin
        if Side < 0 then
        begin
          TextBounds := Rect(0, 0, Width div 2, Height);
          Mark := #$2212;
        end
        else
        begin
          TextBounds := Rect(Width div 2, 0, Width, Height);
          Mark := '+';
        end;
        if (FPressedSide = Side) and Enabled then
          OffsetRect(TextBounds, 0, Stroke);
        DrawText(Canvas.Handle, PChar(Mark), Length(Mark), TextBounds,
          DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
      end;
  end;

  if Focused and Enabled then
  begin
    Ring := Rect(Width div 4, Height div 4, Width * 3 div 4, Height * 3 div 4);
    Canvas.DrawFocusRect(Ring);
  end;
end;

procedure TPanelSurfaceControl.CancelPress;
begin
  FPressedSide := 0;
  FKeyboardKey := 0;
  if MouseCapture then
    MouseCapture := False;
  Invalidate;
end;

procedure TPanelSurfaceControl.MouseDown(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Side: Integer;
begin
  inherited;
  if Button <> mbLeft then
    Exit;
  Side := HitSide(X, Y);
  if (Side = 0) or (FKeyboardKey <> 0) then
    Exit;
  SetFocus;
  FPressedSide := Side;
  FHotSide := Side;
  MouseCapture := True;
  Invalidate;
end;

procedure TPanelSurfaceControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  Side: Integer;
begin
  inherited;
  Side := HitSide(X, Y);
  if FHotSide <> Side then
  begin
    FHotSide := Side;
    Invalidate;
  end;
end;

procedure TPanelSurfaceControl.MouseUp(Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Side: Integer;
begin
  inherited;
  if (Button <> mbLeft) or (FKeyboardKey <> 0) then
    Exit;
  Side := FPressedSide;
  CancelPress;
  { Releasing outside the same half cancels the command. }
  if (Side <> 0) and (HitSide(X, Y) = Side) and Assigned(FOnInvoke) then
    FOnInvoke(Self, Side);
end;

procedure TPanelSurfaceControl.KeyDown(var Key: Word; Shift: TShiftState);
var
  Side: Integer;
begin
  inherited;
  if Key = VK_ESCAPE then
  begin
    CancelPress;
    Key := 0;
    Exit;
  end;
  if not Enabled or not FAvailable or (ssAlt in Shift) or (ssCtrl in Shift) then
    Exit;
  Side := 0;
  if FSplit then
  begin
    if Key in [VK_LEFT, VK_DOWN, VK_SUBTRACT, VK_OEM_MINUS] then
      Side := -1
    else if Key in [VK_RIGHT, VK_UP, VK_ADD, VK_OEM_PLUS] then
      Side := 1;
  end
  else if Key = VK_SPACE then
    Side := 1;
  if Side <> 0 then
  begin
    { One pulse per key release, regardless of Windows key auto-repeat. }
    if (FKeyboardKey = 0) and (FPressedSide = 0) then
    begin
      FKeyboardKey := Key;
      FPressedSide := Side;
      Invalidate;
    end;
    Key := 0;
  end;
end;

procedure TPanelSurfaceControl.KeyUp(var Key: Word; Shift: TShiftState);
var
  Side: Integer;
begin
  inherited;
  if (FKeyboardKey <> 0) and (Key = FKeyboardKey) then
  begin
    Side := FPressedSide;
    CancelPress;
    Key := 0;
    if Focused and Enabled and FAvailable and (Side <> 0) and
      Assigned(FOnInvoke) then
      FOnInvoke(Self, Side);
  end;
end;

procedure TPanelSurfaceControl.SetSelected(Value: Boolean);
begin
  if FSelected <> Value then
  begin
    FSelected := Value;
    Invalidate;
  end;
end;

procedure TPanelSurfaceControl.SetAvailable(Value: Boolean);
begin
  FAvailable := Value;
  TabStop := Value;
  if Value then
    Cursor := crHandPoint
  else
  begin
    Cursor := crDefault;
    CancelPress;
  end;
  Invalidate;
end;

procedure TPanelSurfaceControl.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  FHotSide := 0;
  Invalidate;
end;

procedure TPanelSurfaceControl.CMEnabledChanged(var Message: TMessage);
begin
  inherited;
  FHotSide := 0;
  CancelPress;
end;

procedure TPanelSurfaceControl.WMKillFocus(var Message: TWMKillFocus);
begin
  inherited;
  CancelPress;
end;

procedure TPanelSurfaceControl.WMSetFocus(var Message: TWMSetFocus);
begin
  inherited;
  Invalidate;
end;

procedure TPanelSurfaceControl.WMGetDlgCode(var Message: TWMGetDlgCode);
begin
  inherited;
  Message.Result := Message.Result or DLGC_WANTARROWS or DLGC_WANTCHARS;
end;

procedure TPanelSurfaceControl.WMKeyDown(var Message: TWMKey);
begin
  { Do not re-arm a canceled press while its physical key is still held. }
  if ((Message.KeyData and $40000000) <> 0) and
    (Message.CharCode in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN, VK_SUBTRACT,
      VK_ADD, VK_OEM_MINUS, VK_OEM_PLUS, VK_SPACE]) then
  begin
    Message.Result := 0;
    Exit;
  end;
  inherited;
end;

procedure TPanelSurfaceControl.WMCancelMode(var Message: TMessage);
begin
  inherited;
  CancelPress;
end;

procedure TPanelSurfaceControl.WMCaptureChanged(var Message: TMessage);
begin
  inherited;
  FPressedSide := 0;
  FKeyboardKey := 0;
  Invalidate;
end;

end.
