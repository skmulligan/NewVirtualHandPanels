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
    FCompactMode: Boolean;
    FSyncingCompactControls: Boolean;
    FNormalBounds: TRect;
    FRootPanel: TPanel;
    FTopPanel: TPanel;
    FLeftPanel: TPanel;
    FCenterPanel: TPanel;
    FCompactPanel: TPanel;
    FBackendMode: TComboBox;
    FConnectButton: TButton;
    FCompactConnectButton: TButton;
    FRefreshButton: TButton;
    FCompactRefreshButton: TButton;
    FCompactToggleButton: TButton;
    FFullToggleButton: TButton;
    FControlsList: TListBox;
    FCompactControlCombo: TComboBox;
    FPresetCombo: TComboBox;
    FCompactPresetCombo: TComboBox;
    FFineEdit: TEdit;
    FMediumEdit: TEdit;
    FCoarseEdit: TEdit;
    FBeamShiftModePanel: TGroupBox;
    FBmRadio: TRadioButton;
    FEfccdRadio: TRadioButton;
    FCompactBeamShiftModePanel: TGroupBox;
    FCompactBmRadio: TRadioButton;
    FCompactEfccdRadio: TRadioButton;
    FValueLabel: TLabel;
    FStatusLabel: TLabel;
    FCompactStatusLabel: TLabel;
    FLogMemo: TMemo;
    FJogButtons: array[0..3] of TButton;
    FCompactJogButtons: array[0..3] of TButton;
    FActionButtons: array[TPanelActionId] of TButton;
    procedure BuildUi;
    procedure BuildCompactUi;
    procedure CreateBackend;
    procedure BackendLog(const Text: string);
    procedure BackendUserButtonPressed(Slot: TUserButtonSlot);
    procedure ConnectButtonClick(Sender: TObject);
    procedure RefreshButtonClick(Sender: TObject);
    procedure CompactModeButtonClick(Sender: TObject);
    procedure ControlSelectionChanged(Sender: TObject);
    procedure CompactControlSelectionChanged(Sender: TObject);
    procedure PresetChanged(Sender: TObject);
    procedure CompactPresetChanged(Sender: TObject);
    procedure BeamShiftModeChanged(Sender: TObject);
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
    procedure SetCompactMode(Compact: Boolean);
    procedure SetStatusText(const Text: string);
    procedure SyncCompactSelections;
    procedure SyncBeamShiftMode(Source: TRadioButton);
    function IsBeamShiftEfccdMode: Boolean;
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

  FRootPanel := TPanel.Create(Self);
  FRootPanel.Parent := Self;
  FRootPanel.Align := alClient;
  FRootPanel.BevelOuter := bvNone;

  FTopPanel := TPanel.Create(Self);
  FTopPanel.Parent := FRootPanel;
  FTopPanel.Align := alTop;
  FTopPanel.Height := 52;
  FTopPanel.BevelOuter := bvNone;

  FBackendMode := TComboBox.Create(Self);
  FBackendMode.Parent := FTopPanel;
  FBackendMode.Left := 12;
  FBackendMode.Top := 14;
  FBackendMode.Width := 170;
  FBackendMode.Style := csDropDownList;
  FBackendMode.Items.Add('Simulator');
  FBackendMode.Items.Add('Live TEMScripting');
  FBackendMode.ItemIndex := 0;

  FConnectButton := TButton.Create(Self);
  FConnectButton.Parent := FTopPanel;
  FConnectButton.Left := 194;
  FConnectButton.Top := 12;
  FConnectButton.Width := 96;
  FConnectButton.Height := 28;
  FConnectButton.Caption := 'Connect';
  FConnectButton.OnClick := ConnectButtonClick;

  FRefreshButton := TButton.Create(Self);
  FRefreshButton.Parent := FTopPanel;
  FRefreshButton.Left := 302;
  FRefreshButton.Top := 12;
  FRefreshButton.Width := 120;
  FRefreshButton.Height := 28;
  FRefreshButton.Caption := 'Refresh state';
  FRefreshButton.OnClick := RefreshButtonClick;

  FCompactToggleButton := TButton.Create(Self);
  FCompactToggleButton.Parent := FTopPanel;
  FCompactToggleButton.Left := 434;
  FCompactToggleButton.Top := 12;
  FCompactToggleButton.Width := 88;
  FCompactToggleButton.Height := 28;
  FCompactToggleButton.Caption := 'Compact';
  FCompactToggleButton.OnClick := CompactModeButtonClick;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := FTopPanel;
  FStatusLabel.Left := 538;
  FStatusLabel.Top := 18;
  FStatusLabel.Width := 420;
  FStatusLabel.Caption := 'Disconnected';

  FLeftPanel := TPanel.Create(Self);
  FLeftPanel.Parent := FRootPanel;
  FLeftPanel.Align := alLeft;
  FLeftPanel.Width := 260;
  FLeftPanel.BevelOuter := bvNone;

  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := FLeftPanel;
  LabelControl.Left := 12;
  LabelControl.Top := 8;
  LabelControl.Caption := 'Selected control';

  FControlsList := TListBox.Create(Self);
  FControlsList.Parent := FLeftPanel;
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
  StepPanel.Parent := FLeftPanel;
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
  FBeamShiftModePanel.Parent := FLeftPanel;
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
  FBmRadio.OnClick := BeamShiftModeChanged;

  FEfccdRadio := TRadioButton.Create(Self);
  FEfccdRadio.Parent := FBeamShiftModePanel;
  FEfccdRadio.Left := 100;
  FEfccdRadio.Top := 50;
  FEfccdRadio.Width := 90;
  FEfccdRadio.Caption := 'BM';
  FEfccdRadio.OnClick := BeamShiftModeChanged;

  FCenterPanel := TPanel.Create(Self);
  FCenterPanel.Parent := FRootPanel;
  FCenterPanel.Align := alClient;
  FCenterPanel.BevelOuter := bvNone;

  FValueLabel := TLabel.Create(Self);
  FValueLabel.Parent := FCenterPanel;
  FValueLabel.Left := 16;
  FValueLabel.Top := 14;
  FValueLabel.Width := 600;
  FValueLabel.Height := 42;
  FValueLabel.Font.Size := 12;
  FValueLabel.Caption := 'Connect to read current value.';

  JogPanel := TGroupBox.Create(Self);
  JogPanel.Parent := FCenterPanel;
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
  ActionPanel.Parent := FCenterPanel;
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
  FLogMemo.Parent := FCenterPanel;
  FLogMemo.Left := 16;
  FLogMemo.Top := 286;
  FLogMemo.Width := 720;
  FLogMemo.Height := 292;
  FLogMemo.ScrollBars := ssVertical;
  FLogMemo.ReadOnly := True;

  BuildCompactUi;
end;

procedure TMainForm.BuildCompactUi;
var
  LabelControl: TLabel;
  LabelPreset: TLabel;
  Btn: TButton;
  ListIndex: Integer;
begin
  FCompactPanel := TPanel.Create(Self);
  FCompactPanel.Parent := Self;
  FCompactPanel.Align := alClient;
  FCompactPanel.BevelOuter := bvNone;
  FCompactPanel.Visible := False;

  FCompactConnectButton := TButton.Create(Self);
  FCompactConnectButton.Parent := FCompactPanel;
  FCompactConnectButton.Left := 12;
  FCompactConnectButton.Top := 8;
  FCompactConnectButton.Width := 86;
  FCompactConnectButton.Height := 26;
  FCompactConnectButton.Caption := 'Connect';
  FCompactConnectButton.OnClick := ConnectButtonClick;

  FCompactRefreshButton := TButton.Create(Self);
  FCompactRefreshButton.Parent := FCompactPanel;
  FCompactRefreshButton.Left := 106;
  FCompactRefreshButton.Top := 8;
  FCompactRefreshButton.Width := 96;
  FCompactRefreshButton.Height := 26;
  FCompactRefreshButton.Caption := 'Refresh';
  FCompactRefreshButton.OnClick := RefreshButtonClick;

  FFullToggleButton := TButton.Create(Self);
  FFullToggleButton.Parent := FCompactPanel;
  FFullToggleButton.Left := 210;
  FFullToggleButton.Top := 8;
  FFullToggleButton.Width := 74;
  FFullToggleButton.Height := 26;
  FFullToggleButton.Caption := 'Full';
  FFullToggleButton.OnClick := CompactModeButtonClick;

  FCompactStatusLabel := TLabel.Create(Self);
  FCompactStatusLabel.Parent := FCompactPanel;
  FCompactStatusLabel.Left := 12;
  FCompactStatusLabel.Top := 42;
  FCompactStatusLabel.Width := 272;
  FCompactStatusLabel.Caption := 'Disconnected';

  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := FCompactPanel;
  LabelControl.Left := 12;
  LabelControl.Top := 72;
  LabelControl.Caption := 'Control';

  FCompactControlCombo := TComboBox.Create(Self);
  FCompactControlCombo.Parent := FCompactPanel;
  FCompactControlCombo.Left := 88;
  FCompactControlCombo.Top := 68;
  FCompactControlCombo.Width := 196;
  FCompactControlCombo.Style := csDropDownList;
  for ListIndex := Low(FControlListIds) to High(FControlListIds) do
    FCompactControlCombo.Items.Add(FControls[FControlListIds[ListIndex]].Caption);
  FCompactControlCombo.ItemIndex := 0;
  FCompactControlCombo.OnChange := CompactControlSelectionChanged;

  LabelPreset := TLabel.Create(Self);
  LabelPreset.Parent := FCompactPanel;
  LabelPreset.Left := 12;
  LabelPreset.Top := 106;
  LabelPreset.Caption := 'Preset';

  FCompactPresetCombo := TComboBox.Create(Self);
  FCompactPresetCombo.Parent := FCompactPanel;
  FCompactPresetCombo.Left := 88;
  FCompactPresetCombo.Top := 102;
  FCompactPresetCombo.Width := 196;
  FCompactPresetCombo.Style := csDropDownList;
  FCompactPresetCombo.Items.Add('Fine');
  FCompactPresetCombo.Items.Add('Medium');
  FCompactPresetCombo.Items.Add('Coarse');
  FCompactPresetCombo.ItemIndex := Ord(FPreset);
  FCompactPresetCombo.OnChange := CompactPresetChanged;

  FCompactBeamShiftModePanel := TGroupBox.Create(Self);
  FCompactBeamShiftModePanel.Parent := FCompactPanel;
  FCompactBeamShiftModePanel.Left := 12;
  FCompactBeamShiftModePanel.Top := 134;
  FCompactBeamShiftModePanel.Width := 132;
  FCompactBeamShiftModePanel.Height := 88;
  FCompactBeamShiftModePanel.Caption := 'Beam shift';

  FCompactEfccdRadio := TRadioButton.Create(Self);
  FCompactEfccdRadio.Parent := FCompactBeamShiftModePanel;
  FCompactEfccdRadio.Left := 12;
  FCompactEfccdRadio.Top := 26;
  FCompactEfccdRadio.Width := 92;
  FCompactEfccdRadio.Caption := 'EFCCD';
  FCompactEfccdRadio.Checked := True;
  FCompactEfccdRadio.OnClick := BeamShiftModeChanged;

  FCompactBmRadio := TRadioButton.Create(Self);
  FCompactBmRadio.Parent := FCompactBeamShiftModePanel;
  FCompactBmRadio.Left := 12;
  FCompactBmRadio.Top := 54;
  FCompactBmRadio.Width := 92;
  FCompactBmRadio.Caption := 'BM';
  FCompactBmRadio.OnClick := BeamShiftModeChanged;

  Btn := TButton.Create(Self);
  Btn.Parent := FCompactPanel;
  Btn.Left := 206;
  Btn.Top := 134;
  Btn.Width := 42;
  Btn.Height := 30;
  Btn.Caption := 'Up';
  Btn.Tag := VK_UP;
  Btn.OnClick := JogButtonClick;
  FCompactJogButtons[0] := Btn;

  Btn := TButton.Create(Self);
  Btn.Parent := FCompactPanel;
  Btn.Left := 158;
  Btn.Top := 170;
  Btn.Width := 42;
  Btn.Height := 30;
  Btn.Caption := 'Left';
  Btn.Tag := VK_LEFT;
  Btn.OnClick := JogButtonClick;
  FCompactJogButtons[1] := Btn;

  Btn := TButton.Create(Self);
  Btn.Parent := FCompactPanel;
  Btn.Left := 206;
  Btn.Top := 170;
  Btn.Width := 42;
  Btn.Height := 30;
  Btn.Caption := 'Down';
  Btn.Tag := VK_DOWN;
  Btn.OnClick := JogButtonClick;
  FCompactJogButtons[2] := Btn;

  Btn := TButton.Create(Self);
  Btn.Parent := FCompactPanel;
  Btn.Left := 254;
  Btn.Top := 170;
  Btn.Width := 42;
  Btn.Height := 30;
  Btn.Caption := 'Right';
  Btn.Tag := VK_RIGHT;
  Btn.OnClick := JogButtonClick;
  FCompactJogButtons[3] := Btn;
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
  SetStatusText(FBackend.BackendName + ' disconnected');
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
      FCompactConnectButton.Caption := 'Connect';
      FBackendMode.Enabled := True;
      SetStatusText(FBackend.BackendName + ' disconnected');
      Exit;
    end;

    CreateBackend;
    FBackend.Connect;
    FConnectButton.Caption := 'Disconnect';
    FCompactConnectButton.Caption := 'Disconnect';
    FBackendMode.Enabled := False;
    SetStatusText(FBackend.BackendName + ' connected');
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

procedure TMainForm.CompactModeButtonClick(Sender: TObject);
begin
  SetCompactMode(not FCompactMode);
end;

procedure TMainForm.ControlSelectionChanged(Sender: TObject);
begin
  PersistStepEdits;
  if FControlsList.ItemIndex >= 0 then
    FSelectedId := FControlListIds[FControlsList.ItemIndex];
  LoadStepEdits;
  SyncCompactSelections;
  RefreshSelectedValue;
end;

procedure TMainForm.CompactControlSelectionChanged(Sender: TObject);
begin
  if FSyncingCompactControls or (FCompactControlCombo.ItemIndex < 0) then
    Exit;

  PersistStepEdits;
  FSelectedId := FControlListIds[FCompactControlCombo.ItemIndex];
  if FControlsList.ItemIndex <> FCompactControlCombo.ItemIndex then
    FControlsList.ItemIndex := FCompactControlCombo.ItemIndex;
  LoadStepEdits;
  RefreshSelectedValue;
end;

procedure TMainForm.PresetChanged(Sender: TObject);
begin
  if FPresetCombo.ItemIndex >= 0 then
    SetStepPreset(TStepPreset(FPresetCombo.ItemIndex));
end;

procedure TMainForm.CompactPresetChanged(Sender: TObject);
begin
  if FSyncingCompactControls or (FCompactPresetCombo.ItemIndex < 0) then
    Exit;

  SetStepPreset(TStepPreset(FCompactPresetCombo.ItemIndex));
end;

procedure TMainForm.BeamShiftModeChanged(Sender: TObject);
begin
  if Sender is TRadioButton then
    SyncBeamShiftMode(Sender as TRadioButton);
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
    else if (FSelectedId = pcBeamShift) and IsBeamShiftEfccdMode then
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
  FSyncingCompactControls := True;
  try
    if FPresetCombo.ItemIndex <> Ord(Preset) then
      FPresetCombo.ItemIndex := Ord(Preset);
    if (FCompactPresetCombo <> nil) and
      (FCompactPresetCombo.ItemIndex <> Ord(Preset)) then
      FCompactPresetCombo.ItemIndex := Ord(Preset);
  finally
    FSyncingCompactControls := False;
  end;
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
    if FCompactJogButtons[ButtonIndex] <> nil then
    begin
      FCompactJogButtons[ButtonIndex].Font.Color := PresetColor;
      FCompactJogButtons[ButtonIndex].Font.Style := [fsBold];
    end;
  end;
end;

procedure TMainForm.SetCompactMode(Compact: Boolean);
begin
  if FCompactMode = Compact then
    Exit;

  PersistStepEdits;
  FCompactMode := Compact;

  if Compact then
  begin
    FNormalBounds := BoundsRect;
    SyncCompactSelections;
    FRootPanel.Visible := False;
    FCompactPanel.Visible := True;
    FLogMemo.Parent := FCompactPanel;
    FLogMemo.SetBounds(12, 238, 284, 94);
    SetBounds(Left, Top, 320, 380);
  end
  else
  begin
    FCompactPanel.Visible := False;
    FRootPanel.Visible := True;
    FLogMemo.Parent := FCenterPanel;
    FLogMemo.SetBounds(16, 286, 720, 292);
    if (FNormalBounds.Right > FNormalBounds.Left) and
      (FNormalBounds.Bottom > FNormalBounds.Top) then
      BoundsRect := FNormalBounds;
  end;
end;

procedure TMainForm.SetStatusText(const Text: string);
begin
  if FStatusLabel <> nil then
    FStatusLabel.Caption := Text;
  if FCompactStatusLabel <> nil then
    FCompactStatusLabel.Caption := Text;
end;

procedure TMainForm.SyncCompactSelections;
var
  ListIndex: Integer;
begin
  FSyncingCompactControls := True;
  try
    for ListIndex := Low(FControlListIds) to High(FControlListIds) do
    begin
      if FControlListIds[ListIndex] = FSelectedId then
      begin
        if FControlsList.ItemIndex <> ListIndex then
          FControlsList.ItemIndex := ListIndex;
        if (FCompactControlCombo <> nil) and
          (FCompactControlCombo.ItemIndex <> ListIndex) then
          FCompactControlCombo.ItemIndex := ListIndex;
        Break;
      end;
    end;

    if (FCompactPresetCombo <> nil) and
      (FCompactPresetCombo.ItemIndex <> Ord(FPreset)) then
      FCompactPresetCombo.ItemIndex := Ord(FPreset);
  finally
    FSyncingCompactControls := False;
  end;
end;

procedure TMainForm.SyncBeamShiftMode(Source: TRadioButton);
begin
  if Source = FCompactEfccdRadio then
  begin
    FBmRadio.Checked := FCompactEfccdRadio.Checked;
    FEfccdRadio.Checked := FCompactBmRadio.Checked;
  end
  else if Source = FCompactBmRadio then
  begin
    FBmRadio.Checked := FCompactEfccdRadio.Checked;
    FEfccdRadio.Checked := FCompactBmRadio.Checked;
  end
  else
  begin
    if FCompactEfccdRadio <> nil then
      FCompactEfccdRadio.Checked := FBmRadio.Checked;
    if FCompactBmRadio <> nil then
      FCompactBmRadio.Checked := FEfccdRadio.Checked;
  end;
end;

function TMainForm.IsBeamShiftEfccdMode: Boolean;
begin
  Result := FBmRadio.Checked;
end;

procedure TMainForm.LogException(const Prefix: string; E: Exception);
begin
  BackendLog(Prefix + ': ' + E.Message);
  SetStatusText(Prefix + ': ' + E.Message);
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
