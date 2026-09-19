unit MicroscopeBackend;

interface

uses
  PanelTypes,
  StageSearch;

type
  TBackendLogEvent = procedure(const Text: string) of object;
  TUserButtonPressedEvent = procedure(Slot: TUserButtonSlot) of object;

  IMicroscopeBackend = interface
    ['{29C04A12-4162-4FCB-ABD3-E51507B4E004}']
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

end.
