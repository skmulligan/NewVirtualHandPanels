unit HandPanelView;

interface

uses
  Winapi.Windows,
  System.Classes,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  Vcl.StdCtrls,
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
    FConnectButton: TButton;
    FRefreshButton: TButton;
    FAdvancedButton: TButton;
    FStatusLabel: TLabel;
    FConnected: Boolean;
    FInitialized: Boolean;
    FCommandButtons: array[THandPanelCommand] of TButton;
    FOnCommand: THandPanelCommandEvent;
    procedure BuildUi;
    procedure BuildPanelControls;
    procedure LoadBackground;
    function AddCommandButton(Command: THandPanelCommand;
      const CaptionText, HintText: string; X, Y, W, H: Integer): TButton;
    procedure CommandButtonClick(Sender: TObject);
    procedure BackendModeChanged(Sender: TObject);
    procedure MultifunctionStepsChanged(Sender: TObject);
    procedure LayoutCanvas;
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
    property BackendIndex: Integer read GetBackendIndex write SetBackendIndex;
    property StepPreset: TStepPreset read GetStepPreset write SetStepPreset;
    property OnCommand: THandPanelCommandEvent read FOnCommand write FOnCommand;
  end;

implementation

uses
  System.SysUtils,
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
  FBackground.Proportional := True;
  FBackground.Center := True;
  LoadBackground;

  BuildPanelControls;
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
  Result.Parent := FCanvasPanel;
  Result.SetBounds(X, Y, W, H);
  Result.Caption := CaptionText;
  Result.Hint := HintText;
  Result.ShowHint := True;
  Result.Tag := Ord(Command);
  Result.Font.Name := 'Segoe UI';
  Result.Font.Size := 10;
  Result.Font.Style := [fsBold];
  Result.OnClick := CommandButtonClick;
  FCommandButtons[Command] := Result;
end;

procedure THandPanelView.BuildPanelControls;
var
  StepsLabel: TLabel;
begin
  { Sensitivity selectors near the corresponding physical buttons. }
  AddCommandButton(hpcFine, 'Fine', 'Use the fine step/pulse size',
    374, 143, 72, 38);
  AddCommandButton(hpcCoarse, 'Coarse', 'Use the coarse step/pulse size',
    450, 143, 78, 38);
  AddCommandButton(hpcFine, 'Fine', 'Use the fine step/pulse size',
    588, 143, 72, 38);
  AddCommandButton(hpcCoarse, 'Coarse', 'Use the coarse step/pulse size',
    664, 143, 78, 38);

  AddCommandButton(hpcExposure, 'Exposure',
    'Panel position reserved; backend command is not yet available',
    496, 143, 88, 38);
  AddCommandButton(hpcStigmator, 'Stigmator',
    'Panel position reserved; backend command is not yet available',
    493, 239, 94, 38);

  { Direct TEMScripting controls. }
  AddCommandButton(hpcIntensityDown, '-', 'Decrease intensity',
    382, 237, 40, 40);
  AddCommandButton(hpcIntensityUp, '+', 'Increase intensity',
    426, 237, 40, 40);
  AddCommandButton(hpcMagnificationDown, '-', 'Decrease magnification index',
    924, 237, 40, 40);
  AddCommandButton(hpcMagnificationUp, '+', 'Increase magnification index',
    968, 237, 40, 40);
  AddCommandButton(hpcFocusDown, '-', 'Decrease focus',
    1055, 237, 40, 40);
  AddCommandButton(hpcFocusUp, '+', 'Increase focus',
    1099, 237, 40, 40);

  { Context-sensitive microscope multifunction axes. }
  StepsLabel := TLabel.Create(Self);
  StepsLabel.Parent := FCanvasPanel;
  StepsLabel.SetBounds(595, 193, 68, 24);
  StepsLabel.Caption := 'MF steps';
  StepsLabel.Font.Name := 'Segoe UI';
  StepsLabel.Font.Size := 10;

  FMultifunctionSteps := TComboBox.Create(Self);
  FMultifunctionSteps.Parent := FCanvasPanel;
  FMultifunctionSteps.SetBounds(665, 189, 238, 28);
  FMultifunctionSteps.Style := csDropDownList;
  FMultifunctionSteps.Font.Name := 'Segoe UI';
  FMultifunctionSteps.Font.Size := 10;
  FMultifunctionSteps.Items.Add('1 step (Fine)');
  FMultifunctionSteps.Items.Add('5 steps (Medium)');
  FMultifunctionSteps.Items.Add('10 steps (Coarse)');
  FMultifunctionSteps.ItemIndex := Ord(spMedium);
  FMultifunctionSteps.Hint :=
    'Steps per MF-X/Y click. Shares the Fine/Medium/Coarse preset with other controls.';
  FMultifunctionSteps.ShowHint := True;
  FMultifunctionSteps.OnChange := MultifunctionStepsChanged;

  AddCommandButton(hpcMfXDown, 'X -', 'Send negative MF-X pulses',
    595, 237, 48, 40);
  AddCommandButton(hpcMfXUp, 'X +', 'Send positive MF-X pulses',
    647, 237, 48, 40);
  AddCommandButton(hpcMfYDown, 'Y -', 'Send negative MF-Y pulses',
    803, 237, 48, 40);
  AddCommandButton(hpcMfYUp, 'Y +', 'Send positive MF-Y pulses',
    855, 237, 48, 40);

  { Right-hand action row. }
  AddCommandButton(hpcDarkField, 'Dark Field',
    'Panel position reserved; backend command is not yet available',
    803, 143, 92, 38);
  AddCommandButton(hpcDiffraction, 'Diffraction',
    'Panel position reserved; backend command is not yet available',
    912, 143, 96, 38);
  AddCommandButton(hpcWobbler, 'Wobbler',
    'Panel position reserved; backend command is not yet available',
    1012, 143, 84, 38);
  AddCommandButton(hpcEucentricFocus, 'Euc. Focus',
    'Request eucentric focus', 1100, 143, 96, 38);

  { Stage tilt/Z positions retained as explicit placeholders. }
  AddCommandButton(hpcBetaTiltDown, 'beta -',
    'Panel position reserved; backend command is not yet available',
    68, 191, 64, 34);
  AddCommandButton(hpcBetaTiltUp, 'beta +',
    'Panel position reserved; backend command is not yet available',
    68, 229, 64, 34);
  AddCommandButton(hpcAlphaTiltDown, 'alpha -',
    'Panel position reserved; backend command is not yet available',
    68, 267, 64, 34);
  AddCommandButton(hpcAlphaTiltUp, 'alpha +',
    'Panel position reserved; backend command is not yet available',
    68, 305, 64, 34);
  AddCommandButton(hpcStageZUp, 'Z +',
    'Panel position reserved; backend command is not yet available',
    1352, 210, 72, 38);
  AddCommandButton(hpcStageZDown, 'Z -',
    'Panel position reserved; backend command is not yet available',
    1352, 260, 72, 38);

  { Six user-button locations. }
  AddCommandButton(hpcUserL1, 'L1', 'User button L1', 649, 316, 72, 38);
  AddCommandButton(hpcUserL2, 'L2', 'User button L2', 649, 364, 72, 38);
  AddCommandButton(hpcUserL3, 'L3', 'User button L3', 649, 412, 72, 38);
  AddCommandButton(hpcUserR1, 'R1', 'User button R1', 771, 316, 72, 38);
  AddCommandButton(hpcUserR2, 'R2', 'User button R2', 771, 364, 72, 38);
  AddCommandButton(hpcUserR3, 'R3', 'User button R3', 771, 412, 72, 38);
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
begin
  FMultifunctionSteps.ItemIndex := Ord(Value);
end;

procedure THandPanelView.Resize;
begin
  inherited Resize;
  LayoutCanvas;
  if FAdvancedButton <> nil then
    FAdvancedButton.Left := ClientWidth - FAdvancedButton.Width - 16;
end;

procedure THandPanelView.LayoutCanvas;
begin
  if (FScrollBox = nil) or (FCanvasPanel = nil) then
    Exit;
  if FScrollBox.ClientWidth > PANEL_WIDTH then
    FCanvasPanel.Left := (FScrollBox.ClientWidth - PANEL_WIDTH) div 2
  else
    FCanvasPanel.Left := 0;
  if FScrollBox.ClientHeight > PANEL_HEIGHT then
    FCanvasPanel.Top := (FScrollBox.ClientHeight - PANEL_HEIGHT) div 2
  else
    FCanvasPanel.Top := 0;
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
    if FCanvasPanel.Controls[ControlIndex] is TButton then
      FCanvasPanel.Controls[ControlIndex].Enabled := Enabled;
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
