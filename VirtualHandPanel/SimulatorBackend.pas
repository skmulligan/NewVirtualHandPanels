unit SimulatorBackend;

interface

uses
  System.SysUtils,
  System.SyncObjs,
  PanelTypes,
  MicroscopeBackend,
  StageSearch;

type
  TSimulatorBackend = class(TInterfacedObject, IMicroscopeBackend)
  private
    FConnected: Boolean;
    FLogHandler: TBackendLogEvent;
    FUserButtonPressedHandler: TUserButtonPressedEvent;
    FValues: array[TPanelControlId] of TControlValue;
    FUserButtons: TUserButtonStateArray;
    FSpotsizeIndex: Integer;
    FScreenLifted: Boolean;
    FColumnValvesOpen: Boolean;
    FLock: TCriticalSection;
    procedure Log(const Text: string);
    procedure InitValues;
    procedure InitUserButtons;
  public
    constructor Create;
    destructor Destroy; override;
    procedure SetLogHandler(Handler: TBackendLogEvent);
    procedure SetUserButtonPressedHandler(Handler: TUserButtonPressedEvent);
    function BackendName: string;
    function Connected: Boolean;
    procedure Connect;
    procedure Disconnect;
    function ReadControl(Id: TPanelControlId): TControlValue;
    procedure WriteControl(Id: TPanelControlId; const Value: TControlValue);
    procedure ExecuteAction(Action: TPanelActionId);
    procedure SendMultifunctionPulse(Axis: TMultifunctionAxis; Pulses: Integer);
    function CreateStageMotionSession: IStageMotionSession;
    function RefreshUserButtons: TUserButtonStateArray;
    procedure SimulateUserButtonPress(Slot: TUserButtonSlot);
  end;

implementation

uses
  System.Classes,
  Winapi.Windows;

type
  TSimulatorStageMotionSession = class(TInterfacedObject, IStageMotionSession)
  private
    FOwner: TSimulatorBackend;
    FOpen: Boolean;
    procedure EnsureOpen;
  public
    constructor Create(AOwner: TSimulatorBackend);
    procedure Open;
    procedure Close;
    function GetPosition: TStagePoint;
    function GetLimits: TStageLimits;
    function IsReady: Boolean;
    procedure MoveAxisTo(Axis: TStageAxis; TargetUm, SpeedFraction: Double);
  end;

constructor TSimulatorStageMotionSession.Create(AOwner: TSimulatorBackend);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TSimulatorStageMotionSession.EnsureOpen;
begin
  if not FOpen then
    raise Exception.Create('Simulator stage motion session is not open.');
end;

procedure TSimulatorStageMotionSession.Open;
begin
  FOwner.FLock.Acquire;
  try
    if not FOwner.FConnected then
      raise Exception.Create('Simulator backend is not connected.');
    FOpen := True;
  finally
    FOwner.FLock.Release;
  end;
end;

procedure TSimulatorStageMotionSession.Close;
begin
  FOpen := False;
end;

function TSimulatorStageMotionSession.GetPosition: TStagePoint;
begin
  EnsureOpen;
  FOwner.FLock.Acquire;
  try
    Result.X := FOwner.FValues[pcStage].X;
    Result.Y := FOwner.FValues[pcStage].Y;
  finally
    FOwner.FLock.Release;
  end;
end;

function TSimulatorStageMotionSession.GetLimits: TStageLimits;
begin
  EnsureOpen;
  Result.MinX := -1000;
  Result.MaxX := 1000;
  Result.MinY := -1000;
  Result.MaxY := 1000;
end;

function TSimulatorStageMotionSession.IsReady: Boolean;
begin
  EnsureOpen;
  FOwner.FLock.Acquire;
  try
    Result := FOwner.FConnected;
  finally
    FOwner.FLock.Release;
  end;
end;

procedure TSimulatorStageMotionSession.MoveAxisTo(Axis: TStageAxis;
  TargetUm, SpeedFraction: Double);
begin
  EnsureOpen;
  FOwner.FLock.Acquire;
  try
    if not FOwner.FConnected then
      raise Exception.Create('Simulator backend disconnected during Record Search.');
    if Axis = saX then
      FOwner.FValues[pcStage].X := TargetUm
    else
      FOwner.FValues[pcStage].Y := TargetUm;
  finally
    FOwner.FLock.Release;
  end;
  Sleep(100);
end;

constructor TSimulatorBackend.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  InitValues;
  InitUserButtons;
end;

destructor TSimulatorBackend.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TSimulatorBackend.InitValues;
begin
  FValues[pcFocus].Scalar := 0;
  FValues[pcDefocus].Scalar := -1.50;
  FValues[pcIntensity].Scalar := 0.5000;
  FValues[pcImageShift].X := 0;
  FValues[pcImageShift].Y := 0;
  FValues[pcStage].X := 0;
  FValues[pcStage].Y := 0;
  FValues[pcBeamShift].X := 0;
  FValues[pcBeamShift].Y := 0;
  FValues[pcMagnificationIndex].Scalar := 20;
  FSpotsizeIndex := 5;
  FScreenLifted := False;
  FColumnValvesOpen := False;
end;

procedure TSimulatorBackend.InitUserButtons;
var
  Slot: TUserButtonSlot;
begin
  for Slot := Low(TUserButtonSlot) to High(TUserButtonSlot) do
  begin
    FUserButtons[Slot].Slot := Slot;
    FUserButtons[Slot].Name := UserButtonSlotToString(Slot);
    FUserButtons[Slot].LabelText := 'Sim ' + UserButtonSlotToString(Slot);
    FUserButtons[Slot].Assignment := 'Simulator event';
    FUserButtons[Slot].LastEvent := 0;
    FUserButtons[Slot].EventCount := 0;
  end;
end;

procedure TSimulatorBackend.Log(const Text: string);
begin
  if Assigned(FLogHandler) then
    FLogHandler(Text);
end;

procedure TSimulatorBackend.SetLogHandler(Handler: TBackendLogEvent);
begin
  FLogHandler := Handler;
end;

procedure TSimulatorBackend.SetUserButtonPressedHandler(Handler: TUserButtonPressedEvent);
begin
  FUserButtonPressedHandler := Handler;
end;

function TSimulatorBackend.BackendName: string;
begin
  Result := 'Simulator';
end;

function TSimulatorBackend.Connected: Boolean;
begin
  Result := FConnected;
end;

procedure TSimulatorBackend.Connect;
begin
  FConnected := True;
  Log('Simulator connected.');
end;

procedure TSimulatorBackend.Disconnect;
begin
  FConnected := False;
  Log('Simulator disconnected.');
end;

function TSimulatorBackend.ReadControl(Id: TPanelControlId): TControlValue;
begin
  FLock.Acquire;
  try
    if not FConnected then
      raise Exception.Create('Simulator backend is not connected.');
    Result := FValues[Id];
  finally
    FLock.Release;
  end;
end;

procedure TSimulatorBackend.WriteControl(Id: TPanelControlId; const Value: TControlValue);
begin
  FLock.Acquire;
  try
    if not FConnected then
      raise Exception.Create('Simulator backend is not connected.');
    FValues[Id] := Value;
  finally
    FLock.Release;
  end;
  Log(Format('Simulator set %s to scalar=%0.6f x=%0.6f y=%0.6f',
    [PanelControlIdToString(Id), Value.Scalar, Value.X, Value.Y]));
end;

procedure TSimulatorBackend.ExecuteAction(Action: TPanelActionId);
begin
  if not FConnected then
    raise Exception.Create('Simulator backend is not connected.');

  case Action of
    paOpenColumnValves:
      begin
        FColumnValvesOpen := True;
        Log('Simulator action: column valves opened.');
      end;
    paCloseColumnValves:
      begin
        FColumnValvesOpen := False;
        Log('Simulator action: column valves closed.');
      end;
    paScreenLift:
      begin
        FScreenLifted := True;
        Log('Simulator action: screen lifted.');
      end;
    paScreenDown:
      begin
        FScreenLifted := False;
        Log('Simulator action: screen down.');
      end;
    paResetDefocus:
      begin
        FValues[pcDefocus].Scalar := 0;
        Log('Simulator action: defocus reset to 0.');
      end;
    paEucentricFocus:
      Log('Simulator action: eucentric focus requested.');
    paSpotsizeUp:
      begin
        if FSpotsizeIndex < 11 then
          Inc(FSpotsizeIndex);
        Log('Simulator action: spotsize index ' + IntToStr(FSpotsizeIndex) + '.');
      end;
    paSpotsizeDown:
      begin
        if FSpotsizeIndex > 1 then
          Dec(FSpotsizeIndex);
        Log('Simulator action: spotsize index ' + IntToStr(FSpotsizeIndex) + '.');
      end;
  end;
end;

procedure TSimulatorBackend.SendMultifunctionPulse(Axis: TMultifunctionAxis;
  Pulses: Integer);
var
  AxisName: string;
begin
  if not FConnected then
    raise Exception.Create('Simulator backend is not connected.');
  if Axis = maX then
    AxisName := 'X'
  else
    AxisName := 'Y';
  Log(Format('Simulator MF-%s pulse: %d.', [AxisName, Pulses]));
end;

function TSimulatorBackend.CreateStageMotionSession: IStageMotionSession;
begin
  if not FConnected then
    raise Exception.Create('Simulator backend is not connected.');
  Result := TSimulatorStageMotionSession.Create(Self);
end;

function TSimulatorBackend.RefreshUserButtons: TUserButtonStateArray;
begin
  Result := FUserButtons;
  Log('Simulator user buttons refreshed.');
end;

procedure TSimulatorBackend.SimulateUserButtonPress(Slot: TUserButtonSlot);
begin
  Inc(FUserButtons[Slot].EventCount);
  FUserButtons[Slot].LastEvent := Now;
  Log('Simulator user button pressed: ' + UserButtonSlotToString(Slot));
  if Assigned(FUserButtonPressedHandler) then
    FUserButtonPressedHandler(Slot);
end;

end.
