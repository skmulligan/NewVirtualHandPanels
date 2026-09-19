unit HandPanelView;

interface

uses
  Winapi.Windows,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
  PanelSurfaceControl,
  PanelTypes;

type
  THandPanelCommand = (
    hpcBackendChanged,
    hpcConnect,
    hpcRefresh,
    hpcAdvancedView,
    hpcFine,
    hpcCoarse,
    hpcMultifunctionStepsChanged,
    hpcIntensityDown,
    hpcIntensityUp,
    hpcFocusDown,
    hpcFocusUp,
    hpcMagnificationDown,
    hpcMagnificationUp,
    hpcMfXDown,
    hpcMfXUp,
    hpcMfYDown,
    hpcMfYUp,
    hpcExposure,
    hpcStigmator,
    hpcDarkField,
    hpcDiffraction,
    hpcWobbler,
    hpcEucentricFocus,
    hpcAlphaTiltDown,
    hpcAlphaTiltUp,
    hpcBetaTiltDown,
    hpcBetaTiltUp,
    hpcStageZDown,
    hpcStageZUp,
    hpcUserL1,
    hpcUserL2,
    hpcUserL3,
    hpcUserR1,
    hpcUserR2,
    hpcUserR3
  );

  THandPanelCommandEvent = procedure(Sender: TObject;
    Command: THandPanelCommand) of object;

  THandPanelView = class(TPanel)
  private
    FHeader: TPanel;
    FScrollBox: TScrollBox;
    FCanvasPanel: TPanel;
    FBackground: TImage;
    FBackendMode: TComboBox;
    FMultifunctionSteps: TComboBox;
    FStepsLabel: TLabel;
    FConnectButton: TButton;
    FRefreshButton: TButton;
    FAdvancedButton: TButton;
    FStatusLabel: TLabel;
    FConnected: Boolean;
    FInitialized: Boolean;
    FOnCommand: THandPanelCommandEvent;
    procedure BuildUi;
    procedure BuildPanelControls;
    procedure LoadBackground;
    function AddCommandButton(Command: THandPanelCommand;
      const CaptionText, HintText: string; X, Y, W, H: Integer): TButton;
    function AddSurface(Command: THandPanelCommand; const LabelText: string;
      X, Y, Diameter: Integer; Available: Boolean = True): TPanelSurfaceControl;
    procedure AddKnob(NegativeCommand, PositiveCommand: THandPanelCommand;
      const LabelText: string; X, Y, Diameter: Integer);
    procedure SurfaceInvoked(Sender: TObject; Direction: Integer);
    procedure CommandButtonClick(Sender: TObject);
    procedure BackendModeChanged(Sender: TObject);
    procedure MultifunctionStepsChanged(Sender: TObject);
    procedure LayoutCanvas;
    procedure LayoutHeader;
    function GetBackendIndex: Integer;
    procedure SetBackendIndex(Value: Integer);
    function GetStepPreset: TStepPreset;
    procedure SetStepPreset(Value: TStepPreset);
  protected
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure Initialize;
    procedure SetConnected(Connected: Boolean);
    procedure SetInteractionEnabled(Enabled: Boolean);
    procedure SetStatusText(const Text: string);
    function SurfaceHasFocus: Boolean;
    property BackendIndex: Integer read GetBackendIndex write SetBackendIndex;
    property StepPreset: TStepPreset read GetStepPreset write SetStepPreset;
    property OnCommand: THandPanelCommandEvent read FOnCommand write FOnCommand;
  end;

implementation

uses
  System.SysUtils,
  System.Math,
  System.Types,
  Vcl.Graphics,
  Vcl.Imaging.pngimage;

const
  PANEL_WIDTH = 1500;
  PANEL_HEIGHT = 612;

constructor THandPanelView.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  BevelOuter := bvNone;
  Color := RGB(34, 38, 42);
end;

procedure THandPanelView.Initialize;
begin
  if FInitialized then
    Exit;
  if Parent = nil then
    raise EInvalidOperation.Create(
      'THandPanelView.Initialize requires an assigned parent window.');
  FInitialized := True;
  BuildUi;
end;

procedure THandPanelView.BuildUi;
begin
  FHeader := TPanel.Create(Self);
  FHeader.Parent := Self;
  FHeader.Align := alTop;
  FHeader.Height := 64;
  FHeader.BevelOuter := bvNone;
  FHeader.Color := RGB(45, 50, 55);
  FHeader.ParentBackground := False;
  FHeader.StyleElements := FHeader.StyleElements - [seClient];

  FBackendMode := TComboBox.Create(Self);
  FBackendMode.Parent := FHeader;
  FBackendMode.SetBounds(16, 17, 190, 28);
  FBackendMode.Style := csDropDownList;
  FBackendMode.Items.Add('Simulator');
  FBackendMode.Items.Add('Live TEMScripting');
  FBackendMode.ItemIndex := 1;
  FBackendMode.OnChange := BackendModeChanged;

  FConnectButton := AddCommandButton(hpcConnect, 'Connect',
    'Connect to the selected backend', 220, 12, 116, 38);
  FConnectButton.Parent := FHeader;

  FRefreshButton := AddCommandButton(hpcRefresh, 'Refresh',
    'Refresh the selected microscope value', 348, 12, 104, 38);
  FRefreshButton.Parent := FHeader;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FHeader;
  FStatusLabel.SetBounds(472, 15, 760, 38);
  FStatusLabel.AutoSize := False;
  FStatusLabel.Layout := tlCenter;
  FStatusLabel.Font.Color := clWhite;
  FStatusLabel.Font.Size := 11;
  FStatusLabel.Caption := 'Disconnected';

  FStepsLabel := TLabel.Create(Self);
  FStepsLabel.Parent := FHeader;
  FStepsLabel.Caption := 'MF steps';
  FStepsLabel.Font.Color := clWhite;
  FStepsLabel.Font.Size := 10;

  FMultifunctionSteps := TComboBox.Create(Self);
  FMultifunctionSteps.Parent := FHeader;
  FMultifunctionSteps.Style := csDropDownList;
  FMultifunctionSteps.Items.Add('1 step (Fine)');
  FMultifunctionSteps.Items.Add('5 steps (Medium)');
  FMultifunctionSteps.Items.Add('10 steps (Coarse)');
  FMultifunctionSteps.ItemIndex := Ord(spMedium);
  FMultifunctionSteps.Hint :=
    'Steps per MF-X/Y click. Shares the Fine/Medium/Coarse preset with other controls.';
  FMultifunctionSteps.ShowHint := True;
  FMultifunctionSteps.OnChange := MultifunctionStepsChanged;

  FAdvancedButton := AddCommandButton(hpcAdvancedView, 'Advanced',
    'Open the detailed controls, Record Search, and event log',
    1362, 12, 122, 38);
  FAdvancedButton.Parent := FHeader;

  FScrollBox := TScrollBox.Create(Self);
  FScrollBox.Parent := Self;
  FScrollBox.Align := alClient;
  FScrollBox.BorderStyle := bsNone;
  FScrollBox.Color := clWhite;

  FCanvasPanel := TPanel.Create(Self);
  FCanvasPanel.Parent := FScrollBox;
  FCanvasPanel.SetBounds(0, 0, PANEL_WIDTH, PANEL_HEIGHT);
  FCanvasPanel.BevelOuter := bvNone;
  FCanvasPanel.Color := clWhite;

  FBackground := TImage.Create(Self);
  FBackground.Parent := FCanvasPanel;
  FBackground.Align := alClient;
  FBackground.Stretch := True;
  FBackground.Proportional := False;
  FBackground.Center := True;
  LoadBackground;

  BuildPanelControls;
  LayoutHeader;
  LayoutCanvas;
end;

procedure THandPanelView.LoadBackground;
var
  ResourceStream: TResourceStream;
  Png: TPngImage;
  BackgroundPath: string;
begin
  ResourceStream := nil;
  Png := TPngImage.Create;
  try
    try
      ResourceStream := TResourceStream.Create(HInstance,
        'HAND_PANEL_BACKGROUND', RT_RCDATA);
      Png.LoadFromStream(ResourceStream);
    except
      on E: EResNotFound do
      begin
        BackgroundPath := ExtractFilePath(ParamStr(0)) +
          'HandPanelsBackground.png';
        if FileExists(BackgroundPath) then
          Png.LoadFromFile(BackgroundPath)
        else
        begin
          FBackground.Picture.Graphic := nil;
          Exit;
        end;
      end;
    end;
    FBackground.Picture.Assign(Png);
  finally
    ResourceStream.Free;
    Png.Free;
  end;
end;

function THandPanelView.AddCommandButton(Command: THandPanelCommand;
  const CaptionText, HintText: string; X, Y, W, H: Integer): TButton;
begin
  Result := TButton.Create(Self);
  Result.Parent := FHeader;
  Result.SetBounds(X, Y, W, H);
  Result.Caption := CaptionText;
  Result.Hint := HintText;
  Result.ShowHint := True;
  Result.Tag := Ord(Command);
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 10;
  Result.Font.Style := [fsBold];
  Result.OnClick := CommandButtonClick;
end;

function THandPanelView.AddSurface(Command: THandPanelCommand;
  const LabelText: string; X, Y, Diameter: Integer;
  Available: Boolean): TPanelSurfaceControl;
begin
  Result := TPanelSurfaceControl.Create(Self);
  Result.Parent := FCanvasPanel;
  Result.Artwork := FBackground.Picture;
  Result.DesignBounds := Rect(X, Y, X + Diameter, Y + Diameter);
  Result.SetBounds(X, Y, Diameter, Diameter);
  Result.Caption := LabelText;
  Result.Hint := LabelText;
  if not Available then
    Result.Hint := LabelText + ' (not available)';
  Result.Available := Available;
  Result.Enabled := Available;
  Result.Tag := Ord(Command);
  Result.PositiveCommand := Ord(Command);
  Result.OnInvoke := SurfaceInvoked;
end;

procedure THandPanelView.AddKnob(NegativeCommand,
  PositiveCommand: THandPanelCommand; const LabelText: string;
  X, Y, Diameter: Integer);
var
  Knob: TPanelSurfaceControl;
begin
  Knob := AddSurface(NegativeCommand, LabelText, X, Y, Diameter);
  Knob.Split := True;
  Knob.PositiveCommand := Ord(PositiveCommand);
  Knob.Hint := LabelText + ': left half decreases, right half increases. '
    + 'When focused, use arrow keys or minus/plus; release to send one command.';
end;

procedure THandPanelView.BuildPanelControls;
begin
  { All coordinates refer to the unscaled 1500 x 612 background. Each hit
    area is centered on the face already drawn in the artwork. }
  AddSurface(hpcFine, 'Fine', 392, 143, 38);
  AddSurface(hpcCoarse, 'Coarse', 435, 143, 38);
  AddSurface(hpcFine, 'Fine', 603, 143, 38);
  AddSurface(hpcCoarse, 'Coarse', 645, 143, 38);

  AddSurface(hpcExposure, 'Exposure', 519, 143, 38, False);
  AddSurface(hpcStigmator, 'Stigmator', 518, 237, 38, False);

  AddKnob(hpcIntensityDown, hpcIntensityUp, 'Intensity', 394, 227, 56);
  AddKnob(hpcMfXDown, hpcMfXUp, 'Multifunction X', 613, 224, 56);
  AddKnob(hpcMfYDown, hpcMfYUp, 'Multifunction Y', 822, 224, 56);
  AddKnob(hpcMagnificationDown, hpcMagnificationUp,
    'Magnification', 938, 220, 56);
  AddKnob(hpcFocusDown, hpcFocusUp, 'Focus', 1066, 215, 60);

  AddSurface(hpcDarkField, 'Dark Field', 831, 143, 38, False);
  AddSurface(hpcDiffraction, 'Diffraction', 945, 143, 38, False);
  AddSurface(hpcWobbler, 'Wobbler', 1035, 143, 38, False);
  AddSurface(hpcEucentricFocus, 'Eucentric Focus', 1111, 143, 38, False);

  AddSurface(hpcAlphaTiltDown, 'Alpha tilt decrease', 76, 155, 38, False);
  AddSurface(hpcAlphaTiltUp, 'Alpha tilt increase', 120, 155, 38, False);
  AddSurface(hpcBetaTiltDown, 'Beta tilt decrease', 98, 222, 38, False);
  AddSurface(hpcBetaTiltUp, 'Beta tilt increase', 96, 280, 38, False);
  AddSurface(hpcStageZUp, 'Stage Z increase', 1369, 210, 38, False);
  AddSurface(hpcStageZDown, 'Stage Z decrease', 1370, 267, 38, False);

  AddSurface(hpcUserL1, 'User button L1', 669, 315, 40);
  AddSurface(hpcUserL2, 'User button L2', 669, 362, 40);
  AddSurface(hpcUserL3, 'User button L3', 669, 409, 40);
  AddSurface(hpcUserR1, 'User button R1', 787, 315, 40);
  AddSurface(hpcUserR2, 'User button R2', 787, 362, 40);
  AddSurface(hpcUserR3, 'User button R3', 787, 409, 40);
end;

procedure THandPanelView.SurfaceInvoked(Sender: TObject; Direction: Integer);
var
  Surface: TPanelSurfaceControl;
  Command: THandPanelCommand;
begin
  Surface := Sender as TPanelSurfaceControl;
  if not Surface.Enabled or not Surface.Available or not Assigned(FOnCommand) then
    Exit;
  if Direction > 0 then
    Command := THandPanelCommand(Surface.PositiveCommand)
  else
    Command := THandPanelCommand(Surface.Tag);
  FOnCommand(Self, Command);
end;

procedure THandPanelView.CommandButtonClick(Sender: TObject);
begin
  if Assigned(FOnCommand) and (Sender is TButton) then
    FOnCommand(Self, THandPanelCommand((Sender as TButton).Tag));
end;

procedure THandPanelView.BackendModeChanged(Sender: TObject);
begin
  if Assigned(FOnCommand) then
    FOnCommand(Self, hpcBackendChanged);
end;

procedure THandPanelView.MultifunctionStepsChanged(Sender: TObject);
begin
  if (FMultifunctionSteps.ItemIndex >= 0) and Assigned(FOnCommand) then
    FOnCommand(Self, hpcMultifunctionStepsChanged);
end;

function THandPanelView.GetStepPreset: TStepPreset;
begin
  Result := TStepPreset(FMultifunctionSteps.ItemIndex);
end;

procedure THandPanelView.SetStepPreset(Value: TStepPreset);
var
  Index: Integer;
  Surface: TPanelSurfaceControl;
begin
  FMultifunctionSteps.ItemIndex := Ord(Value);
  for Index := 0 to FCanvasPanel.ControlCount - 1 do
    if FCanvasPanel.Controls[Index] is TPanelSurfaceControl then
    begin
      Surface := TPanelSurfaceControl(FCanvasPanel.Controls[Index]);
      Surface.Selected := ((Surface.Tag = Ord(hpcFine)) and (Value = spFine)) or
        ((Surface.Tag = Ord(hpcCoarse)) and (Value = spCoarse));
    end;
end;

procedure THandPanelView.Resize;
begin
  inherited Resize;
  LayoutHeader;
  LayoutCanvas;
end;

procedure THandPanelView.LayoutCanvas;
var
  CanvasWidth, CanvasHeight, CanvasLeft, CanvasTop: Integer;
  Index: Integer;
  Bounds: TRect;
  Surface: TPanelSurfaceControl;
begin
  if (FScrollBox = nil) or (FCanvasPanel = nil) then
    Exit;
  { Below 1000 logical pixels, scroll rather than shrinking hit areas further. }
  CanvasWidth := Max(MulDiv(1000, Font.PixelsPerInch, 96), FScrollBox.ClientWidth);
  CanvasHeight := MulDiv(CanvasWidth, PANEL_HEIGHT, PANEL_WIDTH);
  CanvasLeft := Max(0, (FScrollBox.ClientWidth - CanvasWidth) div 2);
  CanvasTop := Max(0, (FScrollBox.ClientHeight - CanvasHeight) div 2);
  FCanvasPanel.SetBounds(CanvasLeft - FScrollBox.HorzScrollBar.Position,
    CanvasTop - FScrollBox.VertScrollBar.Position, CanvasWidth, CanvasHeight);
  for Index := 0 to FCanvasPanel.ControlCount - 1 do
    if FCanvasPanel.Controls[Index] is TPanelSurfaceControl then
    begin
      Surface := TPanelSurfaceControl(FCanvasPanel.Controls[Index]);
      Bounds := Surface.DesignBounds;
      Surface.SetBounds(MulDiv(Bounds.Left, CanvasWidth, PANEL_WIDTH),
        MulDiv(Bounds.Top, CanvasHeight, PANEL_HEIGHT),
        MulDiv(Bounds.Right - Bounds.Left, CanvasWidth, PANEL_WIDTH),
        MulDiv(Bounds.Bottom - Bounds.Top, CanvasHeight, PANEL_HEIGHT));
      Surface.Invalidate;
    end;
end;

procedure THandPanelView.LayoutHeader;
var
  ScalePPI: Integer;
  StepsY, StatusY: Integer;
  function S(Value: Integer): Integer;
  begin
    Result := MulDiv(Value, ScalePPI, 96);
  end;
begin
  if (FAdvancedButton = nil) or (FMultifunctionSteps = nil) then
    Exit;
  ScalePPI := Font.PixelsPerInch;
  FBackendMode.SetBounds(S(16), S(17), S(190), S(28));
  FConnectButton.SetBounds(S(220), S(12), S(116), S(38));
  FRefreshButton.SetBounds(S(348), S(12), S(104), S(38));
  if ClientWidth >= S(940) then
  begin
    StepsY := 12;
    StatusY := 54;
    FStepsLabel.SetBounds(S(478), S(23), S(76), S(22));
    FMultifunctionSteps.SetBounds(S(556), S(18), S(210), S(28));
  end
  else
  begin
    StepsY := 58;
    StatusY := 100;
    FStepsLabel.SetBounds(S(16), S(69), S(76), S(22));
    FMultifunctionSteps.SetBounds(S(96), S(64), S(210), S(28));
  end;
  FAdvancedButton.SetBounds(Max(S(320), ClientWidth - S(138)),
    S(StepsY), S(122), S(38));
  FStatusLabel.SetBounds(S(16), S(StatusY), Max(S(100), ClientWidth - S(32)), S(24));
  FStatusLabel.EllipsisPosition := epEndEllipsis;
  FHeader.Height := S(StatusY + 32);
end;

function THandPanelView.SurfaceHasFocus: Boolean;
var
  Index: Integer;
begin
  Result := False;
  for Index := 0 to FCanvasPanel.ControlCount - 1 do
    if (FCanvasPanel.Controls[Index] is TPanelSurfaceControl) and
      TPanelSurfaceControl(FCanvasPanel.Controls[Index]).Focused then
      Exit(True);
end;

function THandPanelView.GetBackendIndex: Integer;
begin
  Result := FBackendMode.ItemIndex;
end;

procedure THandPanelView.SetBackendIndex(Value: Integer);
begin
  if (Value >= 0) and (Value < FBackendMode.Items.Count) then
    FBackendMode.ItemIndex := Value;
end;

procedure THandPanelView.SetConnected(Connected: Boolean);
begin
  FConnected := Connected;
  if Connected then
    FConnectButton.Caption := 'Disconnect'
  else
    FConnectButton.Caption := 'Connect';
  FBackendMode.Enabled := not Connected;
end;

procedure THandPanelView.SetInteractionEnabled(Enabled: Boolean);
var
  ControlIndex: Integer;
begin
  for ControlIndex := 0 to FCanvasPanel.ControlCount - 1 do
    if FCanvasPanel.Controls[ControlIndex] is TPanelSurfaceControl then
      FCanvasPanel.Controls[ControlIndex].Enabled := Enabled and
        TPanelSurfaceControl(FCanvasPanel.Controls[ControlIndex]).Available;
  FConnectButton.Enabled := Enabled;
  FRefreshButton.Enabled := Enabled;
  FMultifunctionSteps.Enabled := Enabled;
  FBackendMode.Enabled := Enabled and not FConnected;
end;

procedure THandPanelView.SetStatusText(const Text: string);
begin
  FStatusLabel.Caption := Text;
end;

end.
