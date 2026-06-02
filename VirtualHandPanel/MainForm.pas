unit MainForm;

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  PanelTypes,
  MicroscopeBackend;

type
  TMainForm = class(TForm)
  private
    FBackend: IMicroscopeBackend;
    FControls: TPanelControlArray;
    FControlListIds: array[0..6] of TPanelControlId;
    FSelectedId: TPanelControlId;
    FPreset: TStepPreset;
    FShuttingDown: Boolean;
    FBackendMode: TComboBox;
    FConnectButton: TButton;
    FRefreshButton: TButton;
    FControlsList: TListBox;
    FPresetCombo: TComboBox;
    FFineEdit: TEdit;
    FMediumEdit: TEdit;
    FCoarseEdit: TEdit;
    FBeamShiftModePanel: TGroupBox;
    FBmRadio: TRadioButton;
    FEfccdRadio: TRadioButton;
    FValueLabel: TLabel;
    FStatusLabel: TLabel;
    FLogMemo: TMemo;
    FJogButtons: array[0..3] of TButton;
    FActionButtons: array[TPanelActionId] of TButton;
    procedure BuildUi;
    procedure CreateBackend;
    procedure BackendLog(const Text: string);
    procedure BackendUserButtonPressed(Slot: TUserButtonSlot);
    procedure ConnectButtonClick(Sender: TObject);
    procedure RefreshButtonClick(Sender: TObject);
    procedure ControlSelectionChanged(Sender: TObject);
    procedure PresetChanged(Sender: TObject);
    procedure StepEditExit(Sender: TObject);
    procedure ActionButtonClick(Sender: TObject);
    procedure JogButtonClick(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PersistStepEdits;
    procedure LoadStepEdits;
    procedure RefreshSelectedValue;
    procedure RefreshUserButtons;
    procedure AdjustSelectedControl(Key: Word);
    procedure AdjustSelectedControlWithStep(Key: Word; Step: Double; const StepLabel: string);
    procedure SetStepPreset(Preset: TStepPreset);
    procedure UpdateJogButtonColors;
    procedure LogException(const Prefix: string; E: Exception);
    function CurrentControl: TPanelControl;
    function CurrentStep: Double;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  frmMain: TMainForm;

implementation

uses
  SimulatorBackend,
  LiveBackend;

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited CreateNew(AOwner);
  FControls := DefaultPanelControls;
  FSelectedId := pcBeamShift;
  FPreset := spMedium;
  BuildUi;
  CreateBackend;
  LoadStepEdits;
  UpdateJogButtonColors;
end;

destructor TMainForm.Destroy;
begin
  FShuttingDown := True;
  if FBackend <> nil then
  begin
    FBackend.SetLogHandler(nil);
    FBackend.SetUserButtonPressedHandler(nil);
    FBackend.Disconnect;
    FBackend := nil;
  end;
  inherited Destroy;
end;

procedure TMainForm.BuildUi;
var
  RootPanel: TPanel;
  TopPanel: TPanel;
  LeftPanel: TPanel;
  CenterPanel: TPanel;
  StepPanel: TGroupBox;
  ActionPanel: TGroupBox;
  JogPanel: TGroupBox;
  LabelControl: TLabel;
  LabelPreset: TLabel;
  LabelFine: TLabel;
  LabelMedium: TLabel;
  LabelCoarse: TLabel;
  LabelBeamShiftMode: TLabel;
  Btn: TButton;
  Action: TPanelActionId;
  ListIndex: Integer;
  Col: Integer;
  Row: Integer;
begin
  Caption := 'Virtual Hand Panel';
  Width := 980;
  Height := 660;
  Position := poScreenCenter;
  BorderStyle := bsSizeable;
  BorderIcons := [biSystemMenu, biMinimize, biMaximize];
  FormStyle := fsStayOnTop;
  KeyPreview := True;
  OnKeyDown := FormKeyDown;

  RootPanel := TPanel.Create(Self);
  RootPanel.Parent := Self;
  RootPanel.Align := alClient;
  RootPanel.BevelOuter := bvNone;

  TopPanel := TPanel.Create(Self);
  TopPanel.Parent := RootPanel;
  TopPanel.Align := alTop;
  TopPanel.Height := 52;
  TopPanel.BevelOuter := bvNone;

  FBackendMode := TComboBox.Create(Self);
  FBackendMode.Parent := TopPanel;
  FBackendMode.Left := 12;
  FBackendMode.Top := 14;
  FBackendMode.Width := 170;
  FBackendMode.Style := csDropDownList;
  FBackendMode.Items.Add('Simulator');
  FBackendMode.Items.Add('Live TEMScripting');
  FBackendMode.ItemIndex := 0;

  FConnectButton := TButton.Create(Self);
  FConnectButton.Parent := TopPanel;
  FConnectButton.Left := 194;
  FConnectButton.Top := 12;
  FConnectButton.Width := 96;
  FConnectButton.Height := 28;
  FConnectButton.Caption := 'Connect';
  FConnectButton.OnClick := ConnectButtonClick;

  FRefreshButton := TButton.Create(Self);
  FRefreshButton.Parent := TopPanel;
  FRefreshButton.Left := 302;
  FRefreshButton.Top := 12;
  FRefreshButton.Width := 120;
  FRefreshButton.Height := 28;
  FRefreshButton.Caption := 'Refresh state';
  FRefreshButton.OnClick := RefreshButtonClick;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := TopPanel;
  FStatusLabel.Left := 440;
  FStatusLabel.Top := 18;
  FStatusLabel.Width := 520;
  FStatusLabel.Caption := 'Disconnected';

  LeftPanel := TPanel.Create(Self);
  LeftPanel.Parent := RootPanel;
  LeftPanel.Align := alLeft;
  LeftPanel.Width := 260;
  LeftPanel.BevelOuter := bvNone;

  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := LeftPanel;
  LabelControl.Left := 12;
  LabelControl.Top := 8;
  LabelControl.Caption := 'Selected control';

  FControlsList := TListBox.Create(Self);
  FControlsList.Parent := LeftPanel;
  FControlsList.Left := 12;
  FControlsList.Top := 28;
  FControlsList.Width := 236;
  FControlsList.Height := 180;
  FControlListIds[0] := pcBeamShift;
  FControlListIds[1] := pcFocus;
  FControlListIds[2] := pcDefocus;
  FControlListIds[3] := pcIntensity;
  FControlListIds[4] := pcImageShift;
  FControlListIds[5] := pcStage;
  FControlListIds[6] := pcMagnificationIndex;
  for ListIndex := Low(FControlListIds) to High(FControlListIds) do
    FControlsList.Items.Add(FControls[FControlListIds[ListIndex]].Caption + ' (' +
      FControls[FControlListIds[ListIndex]].UnitName + ')');
  FControlsList.ItemIndex := 0;
  FControlsList.OnClick := ControlSelectionChanged;

  StepPanel := TGroupBox.Create(Self);
  StepPanel.Parent := LeftPanel;
  StepPanel.Left := 12;
  StepPanel.Top := 220;
  StepPanel.Width := 236;
  StepPanel.Height := 168;
  StepPanel.Caption := 'Step sizes';

  LabelPreset := TLabel.Create(Self);
  LabelPreset.Parent := StepPanel;
  LabelPreset.Left := 12;
  LabelPreset.Top := 28;
  LabelPreset.Caption := 'Preset';

  FPresetCombo := TComboBox.Create(Self);
  FPresetCombo.Parent := StepPanel;
  FPresetCombo.Left := 82;
  FPresetCombo.Top := 24;
  FPresetCombo.Width := 120;
  FPresetCombo.Style := csDropDownList;
  FPresetCombo.Items.Add('Fine');
  FPresetCombo.Items.Add('Medium');
  FPresetCombo.Items.Add('Coarse');
  FPresetCombo.ItemIndex := Ord(FPreset);
  FPresetCombo.OnChange := PresetChanged;

  LabelFine := TLabel.Create(Self);
  LabelFine.Parent := StepPanel;
  LabelFine.Left := 12;
  LabelFine.Top := 62;
  LabelFine.Caption := 'Fine';
  FFineEdit := TEdit.Create(Self);
  FFineEdit.Parent := StepPanel;
  FFineEdit.Left := 82;
  FFineEdit.Top := 58;
  FFineEdit.Width := 120;
  FFineEdit.OnExit := StepEditExit;

  LabelMedium := TLabel.Create(Self);
  LabelMedium.Parent := StepPanel;
  LabelMedium.Left := 12;
  LabelMedium.Top := 94;
  LabelMedium.Caption := 'Medium';
  FMediumEdit := TEdit.Create(Self);
  FMediumEdit.Parent := StepPanel;
  FMediumEdit.Left := 82;
  FMediumEdit.Top := 90;
  FMediumEdit.Width := 120;
  FMediumEdit.OnExit := StepEditExit;

  LabelCoarse := TLabel.Create(Self);
  LabelCoarse.Parent := StepPanel;
  LabelCoarse.Left := 12;
  LabelCoarse.Top := 126;
  LabelCoarse.Caption := 'Coarse';
  FCoarseEdit := TEdit.Create(Self);
  FCoarseEdit.Parent := StepPanel;
  FCoarseEdit.Left := 82;
  FCoarseEdit.Top := 122;
  FCoarseEdit.Width := 120;
  FCoarseEdit.OnExit := StepEditExit;

  FBeamShiftModePanel := TGroupBox.Create(Self);
  FBeamShiftModePanel.Parent := LeftPanel;
  FBeamShiftModePanel.Left := 12;
  FBeamShiftModePanel.Top := 402;
  FBeamShiftModePanel.Width := 236;
  FBeamShiftModePanel.Height := 84;
  FBeamShiftModePanel.Caption := 'Beam shift config';

  LabelBeamShiftMode := TLabel.Create(Self);
  LabelBeamShiftMode.Parent := FBeamShiftModePanel;
  LabelBeamShiftMode.Left := 12;
  LabelBeamShiftMode.Top := 24;
  LabelBeamShiftMode.Width := 210;
  LabelBeamShiftMode.Caption := 'EFCCD reverses jog commands';

  FBmRadio := TRadioButton.Create(Self);
  FBmRadio.Parent := FBeamShiftModePanel;
  FBmRadio.Left := 16;
  FBmRadio.Top := 50;
  FBmRadio.Width := 80;
  FBmRadio.Caption := 'EFCCD';
  FBmRadio.Checked := True;

  FEfccdRadio := TRadioButton.Create(Self);
  FEfccdRadio.Parent := FBeamShiftModePanel;
  FEfccdRadio.Left := 100;
  FEfccdRadio.Top := 50;
  FEfccdRadio.Width := 90;
  FEfccdRadio.Caption := 'BM';

  CenterPanel := TPanel.Create(Self);
  CenterPanel.Parent := RootPanel;
  CenterPanel.Align := alClient;
  CenterPanel.BevelOuter := bvNone;

  FValueLabel := TLabel.Create(Self);
  FValueLabel.Parent := CenterPanel;
  FValueLabel.Left := 16;
  FValueLabel.Top := 14;
  FValueLabel.Width := 600;
  FValueLabel.Height := 42;
  FValueLabel.Font.Size := 12;
  FValueLabel.Caption := 'Connect to read current value.';

  JogPanel := TGroupBox.Create(Self);
  JogPanel.Parent := CenterPanel;
  JogPanel.Left := 16;
  JogPanel.Top := 60;
  JogPanel.Width := 250;
  JogPanel.Height := 172;
  JogPanel.Caption := 'Jog';

  Btn := TButton.Create(Self);
  Btn.Parent := JogPanel;
  Btn.Left := 92;
  Btn.Top := 24;
  Btn.Width := 64;
  Btn.Height := 36;
  Btn.Caption := 'Up';
  Btn.Tag := VK_UP;
  Btn.OnClick := JogButtonClick;
  FJogButtons[0] := Btn;

  Btn := TButton.Create(Self);
  Btn.Parent := JogPanel;
  Btn.Left := 24;
  Btn.Top := 70;
  Btn.Width := 64;
  Btn.Height := 36;
  Btn.Caption := 'Left';
  Btn.Tag := VK_LEFT;
  Btn.OnClick := JogButtonClick;
  FJogButtons[1] := Btn;

  Btn := TButton.Create(Self);
  Btn.Parent := JogPanel;
  Btn.Left := 92;
  Btn.Top := 70;
  Btn.Width := 64;
  Btn.Height := 36;
  Btn.Caption := 'Down';
  Btn.Tag := VK_DOWN;
  Btn.OnClick := JogButtonClick;
  FJogButtons[2] := Btn;

  Btn := TButton.Create(Self);
  Btn.Parent := JogPanel;
  Btn.Left := 160;
  Btn.Top := 70;
  Btn.Width := 64;
  Btn.Height := 36;
  Btn.Caption := 'Right';
  Btn.Tag := VK_RIGHT;
  Btn.OnClick := JogButtonClick;
  FJogButtons[3] := Btn;

  ActionPanel := TGroupBox.Create(Self);
  ActionPanel.Parent := CenterPanel;
  ActionPanel.Left := 290;
  ActionPanel.Top := 60;
  ActionPanel.Width := 410;
  ActionPanel.Height := 180;
  ActionPanel.Caption := 'Actions';

  for Action := Low(TPanelActionId) to High(TPanelActionId) do
  begin
    Col := Ord(Action) mod 2;
    Row := Ord(Action) div 2;

    FActionButtons[Action] := TButton.Create(Self);
    FActionButtons[Action].Parent := ActionPanel;
    FActionButtons[Action].Left := 16 + Col * 194;
    FActionButtons[Action].Top := 28 + Row * 48;
    FActionButtons[Action].Width := 170;
    FActionButtons[Action].Height := 34;
    FActionButtons[Action].Caption := PanelActionIdToString(Action);
    FActionButtons[Action].Tag := Ord(Action);
    FActionButtons[Action].OnClick := ActionButtonClick;
  end;

  FLogMemo := TMemo.Create(Self);
  FLogMemo.Parent := CenterPanel;
  FLogMemo.Left := 16;
  FLogMemo.Top := 286;
  FLogMemo.Width := 720;
  FLogMemo.Height := 292;
  FLogMemo.ScrollBars := ssVertical;
  FLogMemo.ReadOnly := True;
end;

procedure TMainForm.CreateBackend;
begin
  if FBackend <> nil then
    FBackend.Disconnect;

  if FBackendMode.ItemIndex = 1 then
    FBackend := TLiveBackend.Create
  else
    FBackend := TSimulatorBackend.Create;

  FBackend.SetLogHandler(BackendLog);
  FBackend.SetUserButtonPressedHandler(BackendUserButtonPressed);
  FStatusLabel.Caption := FBackend.BackendName + ' disconnected';
end;

procedure TMainForm.BackendLog(const Text: string);
begin
  if FShuttingDown or (FLogMemo = nil) or (FLogMemo.Parent = nil) then
    Exit;
  FLogMemo.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + Text);
end;

procedure TMainForm.BackendUserButtonPressed(Slot: TUserButtonSlot);
begin
  BackendLog('Physical user button event ignored: ' + UserButtonSlotToString(Slot));
end;

procedure TMainForm.ConnectButtonClick(Sender: TObject);
begin
  try
    if FBackend = nil then
      CreateBackend;

    if FBackend.Connected then
    begin
      FBackend.Disconnect;
      FConnectButton.Caption := 'Connect';
      FBackendMode.Enabled := True;
      FStatusLabel.Caption := FBackend.BackendName + ' disconnected';
      Exit;
    end;

    CreateBackend;
    FBackend.Connect;
    FConnectButton.Caption := 'Disconnect';
    FBackendMode.Enabled := False;
    FStatusLabel.Caption := FBackend.BackendName + ' connected';
    RefreshSelectedValue;
  except
    on E: Exception do
      LogException('Connect failed', E);
  end;
end;

procedure TMainForm.RefreshButtonClick(Sender: TObject);
begin
  RefreshSelectedValue;
end;

procedure TMainForm.ControlSelectionChanged(Sender: TObject);
begin
  PersistStepEdits;
  if FControlsList.ItemIndex >= 0 then
    FSelectedId := FControlListIds[FControlsList.ItemIndex];
  LoadStepEdits;
  RefreshSelectedValue;
end;

procedure TMainForm.PresetChanged(Sender: TObject);
begin
  if FPresetCombo.ItemIndex >= 0 then
    SetStepPreset(TStepPreset(FPresetCombo.ItemIndex));
end;

procedure TMainForm.StepEditExit(Sender: TObject);
begin
  PersistStepEdits;
end;

procedure TMainForm.ActionButtonClick(Sender: TObject);
var
  Action: TPanelActionId;
begin
  if FBackend = nil then
    Exit;

  Action := TPanelActionId((Sender as TButton).Tag);
  try
    FBackend.ExecuteAction(Action);
    RefreshSelectedValue;
  except
    on E: Exception do
      LogException(PanelActionIdToString(Action), E);
  end;
end;

procedure TMainForm.JogButtonClick(Sender: TObject);
begin
  AdjustSelectedControl((Sender as TButton).Tag);
end;

procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if ssShift in Shift then
  begin
    case Key of
      Ord('1'):
        begin
          SetStepPreset(spFine);
          Key := 0;
          Exit;
        end;
      Ord('2'):
        begin
          SetStepPreset(spMedium);
          Key := 0;
          Exit;
        end;
      Ord('3'):
        begin
          SetStepPreset(spCoarse);
          Key := 0;
          Exit;
        end;
    end;

    if Key in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN] then
    begin
      PersistStepEdits;
      AdjustSelectedControlWithStep(Key, FControls[FSelectedId].CoarseStep, 'coarse');
      Key := 0;
      Exit;
    end;
  end;

  if Key in [VK_LEFT, VK_RIGHT, VK_UP, VK_DOWN] then
  begin
    PersistStepEdits;
    AdjustSelectedControlWithStep(Key, FControls[FSelectedId].FineStep, 'fine');
    Key := 0;
  end;
end;

procedure TMainForm.PersistStepEdits;
var
  Control: TPanelControl;
  Value: Double;
begin
  Control := FControls[FSelectedId];
  if TryStrToFloat(FFineEdit.Text, Value) then
    Control.FineStep := Value;
  if TryStrToFloat(FMediumEdit.Text, Value) then
    Control.MediumStep := Value;
  if TryStrToFloat(FCoarseEdit.Text, Value) then
    Control.CoarseStep := Value;
  FControls[FSelectedId] := Control;
end;

procedure TMainForm.LoadStepEdits;
var
  Control: TPanelControl;
begin
  Control := FControls[FSelectedId];
  FFineEdit.Text := FloatToStr(Control.FineStep);
  FMediumEdit.Text := FloatToStr(Control.MediumStep);
  FCoarseEdit.Text := FloatToStr(Control.CoarseStep);
end;

procedure TMainForm.RefreshSelectedValue;
var
  Value: TControlValue;
  Control: TPanelControl;
begin
  if (FBackend = nil) or not FBackend.Connected then
  begin
    FValueLabel.Caption := 'Connect to read current value.';
    Exit;
  end;

  try
    Control := CurrentControl;
    Value := FBackend.ReadControl(FSelectedId);
    case Control.Kind of
      ckScalar, ckIndex:
        FValueLabel.Caption := Format('%s: %0.6f %s',
          [Control.Caption, Value.Scalar, Control.UnitName]);
      ckVector:
        FValueLabel.Caption := Format('%s: X=%0.6f, Y=%0.6f %s',
          [Control.Caption, Value.X, Value.Y, Control.UnitName]);
    end;
  except
    on E: Exception do
      LogException('Refresh selected value', E);
  end;
end;

procedure TMainForm.RefreshUserButtons;
begin
  { Hardware user buttons are no longer displayed in this panel. }
end;

procedure TMainForm.AdjustSelectedControl(Key: Word);
begin
  AdjustSelectedControlWithStep(Key, CurrentStep, StepPresetToString(FPreset));
end;

procedure TMainForm.AdjustSelectedControlWithStep(Key: Word; Step: Double; const StepLabel: string);
var
  Value: TControlValue;
  Control: TPanelControl;
  Direction: Double;
begin
  PersistStepEdits;
  if (FBackend = nil) or not FBackend.Connected then
  begin
    BackendLog('No backend connection for jog.');
    Exit;
  end;

  try
    Control := CurrentControl;
    Value := FBackend.ReadControl(FSelectedId);

    if Control.Kind in [ckScalar, ckIndex] then
    begin
      if Key in [VK_RIGHT, VK_UP] then
        Direction := 1
      else
        Direction := -1;
      Value.Scalar := Value.Scalar + Direction * Step;
    end
    else if (FSelectedId = pcBeamShift) and FBmRadio.Checked then
    begin
      case Key of
        VK_LEFT: Value.X := Value.X + Step;
        VK_RIGHT: Value.X := Value.X - Step;
        VK_UP: Value.Y := Value.Y - Step;
        VK_DOWN: Value.Y := Value.Y + Step;
      end;
      BackendLog('Beam shift EFCCD mode: sent reversed jog command.');
    end
    else
    begin
      case Key of
        VK_LEFT: Value.X := Value.X - Step;
        VK_RIGHT: Value.X := Value.X + Step;
        VK_UP: Value.Y := Value.Y + Step;
        VK_DOWN: Value.Y := Value.Y - Step;
      end;
    end;

    FBackend.WriteControl(FSelectedId, Value);
    if StepLabel <> '' then
      BackendLog('Jog step: ' + StepLabel + '.');
    RefreshSelectedValue;
  except
    on E: Exception do
      LogException('Jog failed', E);
  end;
end;

procedure TMainForm.SetStepPreset(Preset: TStepPreset);
begin
  FPreset := Preset;
  if FPresetCombo.ItemIndex <> Ord(Preset) then
    FPresetCombo.ItemIndex := Ord(Preset);
  UpdateJogButtonColors;
  BackendLog('Step preset: ' + StepPresetToString(Preset));
end;

procedure TMainForm.UpdateJogButtonColors;
var
  ButtonIndex: Integer;
  PresetColor: TColor;
begin
  case FPreset of
    spFine: PresetColor := clGreen;
    spMedium: PresetColor := clYellow;
    spCoarse: PresetColor := clRed;
  else
    PresetColor := clWindowText;
  end;

  for ButtonIndex := Low(FJogButtons) to High(FJogButtons) do
  begin
    if FJogButtons[ButtonIndex] <> nil then
    begin
      FJogButtons[ButtonIndex].Font.Color := PresetColor;
      FJogButtons[ButtonIndex].Font.Style := [fsBold];
    end;
  end;
end;

procedure TMainForm.LogException(const Prefix: string; E: Exception);
begin
  BackendLog(Prefix + ': ' + E.Message);
  FStatusLabel.Caption := Prefix + ': ' + E.Message;
end;

procedure TMainForm.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := (Params.ExStyle and not WS_EX_TOOLWINDOW) or WS_EX_APPWINDOW;
end;

function TMainForm.CurrentControl: TPanelControl;
begin
  Result := FControls[FSelectedId];
end;

function TMainForm.CurrentStep: Double;
begin
  Result := StepForPreset(CurrentControl, FPreset);
end;

end.
