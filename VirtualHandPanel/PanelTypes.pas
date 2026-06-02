unit PanelTypes;

interface

uses
  System.SysUtils;

type
  TPanelControlId = (
    pcFocus,
    pcDefocus,
    pcIntensity,
    pcImageShift,
    pcStage,
    pcBeamShift,
    pcMagnificationIndex
  );

  TPanelControlKind = (ckScalar, ckVector, ckIndex);
  TStepPreset = (spFine, spMedium, spCoarse);
  TPanelActionId = (
    paScreenLift,
    paScreenDown,
    paResetDefocus,
    paEucentricFocus,
    paSpotsizeDown,
    paSpotsizeUp
  );

  TPanelControl = record
    Id: TPanelControlId;
    Caption: string;
    UnitName: string;
    Kind: TPanelControlKind;
    FineStep: Double;
    MediumStep: Double;
    CoarseStep: Double;
  end;

  TControlValue = record
    Scalar: Double;
    X: Double;
    Y: Double;
  end;

  TUserButtonSlot = (ubL1, ubL2, ubL3, ubR1, ubR2, ubR3);

  TUserButtonState = record
    Slot: TUserButtonSlot;
    Name: string;
    LabelText: string;
    Assignment: string;
    LastEvent: TDateTime;
    EventCount: Integer;
  end;

  TPanelControlArray = array[TPanelControlId] of TPanelControl;
  TUserButtonStateArray = array[TUserButtonSlot] of TUserButtonState;

function DefaultPanelControls: TPanelControlArray;
function PanelControlIdToString(Id: TPanelControlId): string;
function UserButtonSlotToString(Slot: TUserButtonSlot): string;
function PanelActionIdToString(Action: TPanelActionId): string;
function StepPresetToString(Preset: TStepPreset): string;
function StepForPreset(const Control: TPanelControl; Preset: TStepPreset): Double;

implementation

function MakeControl(
  Id: TPanelControlId;
  const Caption, UnitName: string;
  Kind: TPanelControlKind;
  FineStep, MediumStep, CoarseStep: Double): TPanelControl;
begin
  Result.Id := Id;
  Result.Caption := Caption;
  Result.UnitName := UnitName;
  Result.Kind := Kind;
  Result.FineStep := FineStep;
  Result.MediumStep := MediumStep;
  Result.CoarseStep := CoarseStep;
end;

function DefaultPanelControls: TPanelControlArray;
begin
  Result[pcFocus] := MakeControl(pcFocus, 'Focus', 'raw focus units', ckScalar, 0.00001, 0.00005, 0.00010);
  Result[pcDefocus] := MakeControl(pcDefocus, 'Defocus', 'um', ckScalar, 0.01, 0.05, 0.10);
  Result[pcIntensity] := MakeControl(pcIntensity, 'Intensity', 'normalized', ckScalar, 0.0001, 0.0005, 0.0010);
  Result[pcImageShift] := MakeControl(pcImageShift, 'Image shift', 'um', ckVector, 0.01, 0.05, 0.10);
  Result[pcStage] := MakeControl(pcStage, 'Stage X/Y', 'um', ckVector, 0.05, 0.25, 1.00);
  Result[pcBeamShift] := MakeControl(pcBeamShift, 'Beam shift', 'um', ckVector, 0.01, 0.05, 0.10);
  Result[pcMagnificationIndex] := MakeControl(pcMagnificationIndex, 'Magnification index', 'index', ckIndex, 1, 1, 5);
end;

function PanelControlIdToString(Id: TPanelControlId): string;
begin
  case Id of
    pcFocus: Result := 'Focus';
    pcDefocus: Result := 'Defocus';
    pcIntensity: Result := 'Intensity';
    pcImageShift: Result := 'Image shift';
    pcStage: Result := 'Stage X/Y';
    pcBeamShift: Result := 'Beam shift';
    pcMagnificationIndex: Result := 'Magnification index';
  else
    Result := 'Unknown';
  end;
end;

function UserButtonSlotToString(Slot: TUserButtonSlot): string;
begin
  case Slot of
    ubL1: Result := 'L1';
    ubL2: Result := 'L2';
    ubL3: Result := 'L3';
    ubR1: Result := 'R1';
    ubR2: Result := 'R2';
    ubR3: Result := 'R3';
  else
    Result := '?';
  end;
end;

function PanelActionIdToString(Action: TPanelActionId): string;
begin
  case Action of
    paScreenLift: Result := 'Screen Lift';
    paScreenDown: Result := 'Screen Down';
    paResetDefocus: Result := 'Reset Defocus';
    paEucentricFocus: Result := 'Eucentric Focus';
    paSpotsizeDown: Result := 'Spotsize -';
    paSpotsizeUp: Result := 'Spotsize +';
  else
    Result := 'Unknown action';
  end;
end;

function StepPresetToString(Preset: TStepPreset): string;
begin
  case Preset of
    spFine: Result := 'Fine';
    spMedium: Result := 'Medium';
    spCoarse: Result := 'Coarse';
  else
    Result := 'Unknown';
  end;
end;

function StepForPreset(const Control: TPanelControl; Preset: TStepPreset): Double;
begin
  case Preset of
    spFine: Result := Control.FineStep;
    spMedium: Result := Control.MediumStep;
    spCoarse: Result := Control.CoarseStep;
  else
    Result := Control.MediumStep;
  end;
end;

end.
