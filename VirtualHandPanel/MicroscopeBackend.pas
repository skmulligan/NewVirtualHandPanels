unit MicroscopeBackend;

interface

uses
  PanelTypes;

type
  TBackendLogEvent = procedure(const Text: string) of object;
  TUserButtonPressedEvent = procedure(Slot: TUserButtonSlot) of object;

  IMicroscopeBackend = interface
    ['{97315169-D905-4AF2-9584-6A1D4F2DCB6B}']
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

end.
