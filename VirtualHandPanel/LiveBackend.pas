unit LiveBackend;

interface

uses
  System.SysUtils,
  System.Classes,
  PanelTypes,
  MicroscopeBackend,
  TEMScriptingEvents,
  TemScripting_TLB;

type
  TLiveBackend = class(TInterfacedObject, IMicroscopeBackend)
  private
    FConnected: Boolean;
    FLogHandler: TBackendLogEvent;
    FUserButtonPressedHandler: TUserButtonPressedEvent;
    FTem: Instrument;
    FButtons: UserButtons;
    FButton: array[TUserButtonSlot] of UserButton;
    FButtonEvents: array[TUserButtonSlot] of TUserButtonEvent;
    FUserButtons: TUserButtonStateArray;
    procedure Log(const Text: string);
    procedure EnsureConnected;
    procedure EnsureUserButtons;
    procedure ConnectUserButtonEvents;
    procedure DisconnectUserButtonEvents;
    procedure UserButtonPressed(Sender: TObject);
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
    function RefreshUserButtons: TUserButtonStateArray;
    procedure SimulateUserButtonPress(Slot: TUserButtonSlot);
  end;

implementation

constructor TLiveBackend.Create;
var
  Slot: TUserButtonSlot;
begin
  inherited Create;
  for Slot := Low(TUserButtonSlot) to High(TUserButtonSlot) do
  begin
    FUserButtons[Slot].Slot := Slot;
    FUserButtons[Slot].Name := UserButtonSlotToString(Slot);
    FUserButtons[Slot].LabelText := '';
    FUserButtons[Slot].Assignment := '';
    FUserButtons[Slot].LastEvent := 0;
    FUserButtons[Slot].EventCount := 0;

    FButtonEvents[Slot] := TUserButtonEvent.Create(nil);
    FButtonEvents[Slot].Name := 'UserButtonEvent' + UserButtonSlotToString(Slot);
    FButtonEvents[Slot].Pressed := UserButtonPressed;
  end;
end;

destructor TLiveBackend.Destroy;
var
  Slot: TUserButtonSlot;
begin
  Disconnect;
  for Slot := Low(TUserButtonSlot) to High(TUserButtonSlot) do
    FButtonEvents[Slot].Free;
  inherited Destroy;
end;

procedure TLiveBackend.Log(const Text: string);
begin
  if Assigned(FLogHandler) then
    FLogHandler(Text);
end;

procedure TLiveBackend.SetLogHandler(Handler: TBackendLogEvent);
begin
  FLogHandler := Handler;
end;

procedure TLiveBackend.SetUserButtonPressedHandler(Handler: TUserButtonPressedEvent);
begin
  FUserButtonPressedHandler := Handler;
end;

function TLiveBackend.BackendName: string;
begin
  Result := 'Live TEMScripting';
end;

function TLiveBackend.Connected: Boolean;
begin
  Result := FConnected;
end;

procedure TLiveBackend.EnsureConnected;
begin
  if not FConnected or (FTem = nil) then
    raise Exception.Create('Live TEMScripting backend is not connected.');
end;

procedure TLiveBackend.Connect;
begin
  if FConnected then
    Exit;

  try
    FTem := CoInstrument.Create;
    FConnected := True;
    Log('Connected to TEMScripting instrument.');
  except
    on E: Exception do
    begin
      FTem := nil;
      FConnected := False;
      raise Exception.Create('Could not connect to TEMScripting instrument: ' + E.Message);
    end;
  end;
end;

procedure TLiveBackend.Disconnect;
begin
  DisconnectUserButtonEvents;
  FButtons := nil;
  FTem := nil;
  FConnected := False;
  Log('Disconnected from TEMScripting instrument.');
end;

procedure TLiveBackend.EnsureUserButtons;
var
  Slot: TUserButtonSlot;
  Index: Integer;
begin
  EnsureConnected;
  if FButtons <> nil then
    Exit;

  FButtons := FTem.UserButtons;
  for Slot := Low(TUserButtonSlot) to High(TUserButtonSlot) do
  begin
    Index := Ord(Slot);
    if (FButtons <> nil) and (Index < FButtons.Count) then
      FButton[Slot] := FButtons.Item[Index]
    else
      FButton[Slot] := nil;
  end;
end;

procedure TLiveBackend.ConnectUserButtonEvents;
var
  Slot: TUserButtonSlot;
begin
  EnsureUserButtons;
  for Slot := Low(TUserButtonSlot) to High(TUserButtonSlot) do
  begin
    if FButton[Slot] <> nil then
      FButtonEvents[Slot].Connect(IUnknown(FButton[Slot]));
  end;
  Log('User button event sinks connected.');
end;

procedure TLiveBackend.DisconnectUserButtonEvents;
var
  Slot: TUserButtonSlot;
begin
  for Slot := Low(TUserButtonSlot) to High(TUserButtonSlot) do
    if FButtonEvents[Slot] <> nil then
      FButtonEvents[Slot].Disconnect;
end;

procedure TLiveBackend.UserButtonPressed(Sender: TObject);
var
  Slot: TUserButtonSlot;
begin
  for Slot := Low(TUserButtonSlot) to High(TUserButtonSlot) do
  begin
    if Sender = FButtonEvents[Slot] then
    begin
      Inc(FUserButtons[Slot].EventCount);
      FUserButtons[Slot].LastEvent := Now;
      Log('User button pressed: ' + UserButtonSlotToString(Slot));
      if Assigned(FUserButtonPressedHandler) then
        FUserButtonPressedHandler(Slot);
      Exit;
    end;
  end;
end;

function TLiveBackend.ReadControl(Id: TPanelControlId): TControlValue;
var
  Vec: Vector;
  Pos: StagePosition;
begin
  EnsureConnected;
  Result.Scalar := 0;
  Result.X := 0;
  Result.Y := 0;

  case Id of
    pcFocus:
      Result.Scalar := FTem.Projection.Focus;
    pcDefocus:
      Result.Scalar := FTem.Projection.Defocus * 1e6;
    pcIntensity:
      Result.Scalar := FTem.Illumination.Intensity;
    pcImageShift:
      begin
        Vec := FTem.Projection.ImageShift;
        Result.X := Vec.X * 1e6;
        Result.Y := Vec.Y * 1e6;
      end;
    pcStage:
      begin
        Pos := FTem.Stage.Position;
        Result.X := Pos.X * 1e6;
        Result.Y := Pos.Y * 1e6;
      end;
    pcBeamShift:
      begin
        Vec := FTem.Illumination.Shift;
        Result.X := Vec.X * 1e6;
        Result.Y := Vec.Y * 1e6;
      end;
    pcMagnificationIndex:
      Result.Scalar := FTem.Projection.MagnificationIndex;
  end;
end;

procedure TLiveBackend.WriteControl(Id: TPanelControlId; const Value: TControlValue);
var
  Vec: Vector;
  Pos: StagePosition;
begin
  EnsureConnected;

  case Id of
    pcFocus:
      FTem.Projection.Focus := Value.Scalar;
    pcDefocus:
      FTem.Projection.Defocus := Value.Scalar / 1e6;
    pcIntensity:
      FTem.Illumination.Intensity := Value.Scalar;
    pcImageShift:
      begin
        Vec := FTem.Projection.ImageShift;
        Vec.X := Value.X / 1e6;
        Vec.Y := Value.Y / 1e6;
        FTem.Projection.ImageShift := Vec;
      end;
    pcStage:
      begin
        Pos := FTem.Stage.Position;
        Pos.X := Value.X / 1e6;
        Pos.Y := Value.Y / 1e6;
        FTem.Stage.MoveTo(Pos, axisX or axisY);
      end;
    pcBeamShift:
      begin
        Vec := FTem.Illumination.Shift;
        Vec.X := Value.X / 1e6;
        Vec.Y := Value.Y / 1e6;
        FTem.Illumination.Shift := Vec;
      end;
    pcMagnificationIndex:
      FTem.Projection.MagnificationIndex := Round(Value.Scalar);
  end;

  Log('Set ' + PanelControlIdToString(Id) + ' on live microscope.');
end;

procedure TLiveBackend.ExecuteAction(Action: TPanelActionId);
var
  Spotsize: Integer;
begin
  EnsureConnected;

  case Action of
    paScreenLift:
      begin
        FTem.Camera.MainScreen := spUp;
        Log('Action complete: screen lifted.');
      end;
    paScreenDown:
      begin
        FTem.Camera.MainScreen := spDown;
        Log('Action complete: screen down.');
      end;
    paResetDefocus:
      begin
        FTem.Projection.ResetDefocus;
        Log('Action complete: defocus reset.');
      end;
    paEucentricFocus:
      begin
        Log('Eucentric Focus is not exposed by the bundled TEMScripting type library.');
      end;
    paSpotsizeUp:
      begin
        Spotsize := FTem.Illumination.SpotsizeIndex;
        if Spotsize < 11 then
          Inc(Spotsize);
        FTem.Illumination.SpotsizeIndex := Spotsize;
        Log('Action complete: spotsize index ' + IntToStr(Spotsize) + '.');
      end;
    paSpotsizeDown:
      begin
        Spotsize := FTem.Illumination.SpotsizeIndex;
        if Spotsize > 1 then
          Dec(Spotsize);
        FTem.Illumination.SpotsizeIndex := Spotsize;
        Log('Action complete: spotsize index ' + IntToStr(Spotsize) + '.');
      end;
  end;
end;

function TLiveBackend.RefreshUserButtons: TUserButtonStateArray;
var
  Slot: TUserButtonSlot;
begin
  EnsureUserButtons;
  for Slot := Low(TUserButtonSlot) to High(TUserButtonSlot) do
  begin
    FUserButtons[Slot].Slot := Slot;
    if FButton[Slot] <> nil then
    begin
      FUserButtons[Slot].Name := FButton[Slot].Name;
      FUserButtons[Slot].LabelText := FButton[Slot].Label_;
      FUserButtons[Slot].Assignment := FButton[Slot].Assignment;
    end
    else
    begin
      FUserButtons[Slot].Name := UserButtonSlotToString(Slot);
      FUserButtons[Slot].LabelText := '';
      FUserButtons[Slot].Assignment := 'Unavailable';
    end;
  end;
  Result := FUserButtons;
  Log('Live user buttons refreshed.');
end;

procedure TLiveBackend.SimulateUserButtonPress(Slot: TUserButtonSlot);
begin
  raise Exception.Create('Simulated button press is only available in simulator mode.');
end;

end.
