unit StageSearch;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  Winapi.Windows;

const
  RECORD_SEARCH_STRIDE_FRACTION = 0.75;
  RECORD_SEARCH_CHUNK_FRACTION = 0.10;
  RECORD_SEARCH_MOVE_TIMEOUT_MS = 30000;
  RECORD_SEARCH_POSITION_TOLERANCE_UM = 0.005;

type
  EStageSearchBoundary = class(Exception);
  EStageHardwareLimit = class(Exception);

  TStagePoint = record
    X: Double;
    Y: Double;
  end;

  TStageLimits = record
    MinX: Double;
    MaxX: Double;
    MinY: Double;
    MaxY: Double;
  end;

  TStageAxis = (saX, saY);
  TStageGridPoint = record
    X: Integer;
    Y: Integer;
  end;

  TStageSpiralCursor = record
    GridX: Integer;
    GridY: Integer;
    DirectionIndex: Integer;
    LegLength: Integer;
    StepsRemaining: Integer;
    LegsAtCurrentLength: Integer;
  end;

  TStageSearchState = (sssIdle, sssRunning, sssStopping);
  TStageSearchFinishReason = (sfrStopped, sfrBoundaryReached,
    sfrHardwareLimit, sfrError);

  TStageSearchSettings = record
    PixelSizeAngstrom: Double;
    ImageWidthPixels: Integer;
    ImageHeightPixels: Integer;
    SpeedFraction: Double;
    MaxExtentUm: Double;
  end;

  TStageSearchGeometry = record
    FovXUm: Double;
    FovYUm: Double;
    StrideXUm: Double;
    StrideYUm: Double;
    ChunkXUm: Double;
    ChunkYUm: Double;
  end;

  IStageMotionSession = interface
    ['{C4E64D12-D82C-4DD1-AC90-59B842B77BD5}']
    procedure Open;
    procedure Close;
    function GetPosition: TStagePoint;
    function GetLimits: TStageLimits;
    function IsReady: Boolean;
    procedure MoveAxisTo(Axis: TStageAxis; TargetUm, SpeedFraction: Double);
  end;

  TStageSearchStartedEvent = procedure(const Origin: TStagePoint;
    const Limits: TStageLimits) of object;
  TStageSearchProgressEvent = procedure(Ring, GridX, GridY: Integer;
    const Position: TStagePoint) of object;
  TStageSearchCompleteEvent = procedure(Reason: TStageSearchFinishReason;
    const Detail: string; const FinalPosition: TStagePoint) of object;

  TStageSearchController = class;

  TStageSearchThread = class(TThread)
  private
    FOwner: TStageSearchController;
    FSession: IStageMotionSession;
    FSettings: TStageSearchSettings;
    FGeometry: TStageSearchGeometry;
    FStopRequested: Integer;
    FOrigin: TStagePoint;
    FLimits: TStageLimits;
    FLastPosition: TStagePoint;
    procedure QueueStarted;
    procedure QueueProgress(Ring, GridX, GridY: Integer;
      const Position: TStagePoint);
    procedure QueueCompleted(Reason: TStageSearchFinishReason;
      const Detail: string; const Position: TStagePoint);
    procedure WaitForStageReady;
    procedure MoveToGridPoint(GridX, GridY: Integer);
    procedure MoveAxisInChunks(Axis: TStageAxis; TargetUm, ChunkUm: Double);
    function StopWasRequested: Boolean;
    function PointWithinSearchBoundary(const Point: TStagePoint): Boolean;
    function PointWithinHardwareLimits(const Point: TStagePoint): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TStageSearchController;
      const Session: IStageMotionSession; const Settings: TStageSearchSettings;
      const Geometry: TStageSearchGeometry);
    procedure RequestStop;
  end;

  TStageSearchController = class
  private
    FThread: TStageSearchThread;
    FState: TStageSearchState;
    FOnStarted: TStageSearchStartedEvent;
    FOnProgress: TStageSearchProgressEvent;
    FOnComplete: TStageSearchCompleteEvent;
    procedure ReleaseCompletedThread;
    procedure DeliverStarted(const Origin: TStagePoint;
      const Limits: TStageLimits);
    procedure DeliverProgress(Ring, GridX, GridY: Integer;
      const Position: TStagePoint);
    procedure DeliverCompleted(Reason: TStageSearchFinishReason;
      const Detail: string; const FinalPosition: TStagePoint);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start(const Session: IStageMotionSession;
      const Settings: TStageSearchSettings;
      const Geometry: TStageSearchGeometry);
    procedure Stop;
    function Active: Boolean;
    property State: TStageSearchState read FState;
    property OnStarted: TStageSearchStartedEvent read FOnStarted write FOnStarted;
    property OnProgress: TStageSearchProgressEvent read FOnProgress write FOnProgress;
    property OnComplete: TStageSearchCompleteEvent read FOnComplete write FOnComplete;
  end;

function TryBuildStageSearchGeometry(const Settings: TStageSearchSettings;
  out Geometry: TStageSearchGeometry; out ErrorText: string): Boolean;
procedure InitializeSpiralCursor(out Cursor: TStageSpiralCursor);
function AdvanceSquareSpiral(var Cursor: TStageSpiralCursor): TStageGridPoint;
function StageSearchFinishReasonToString(Reason: TStageSearchFinishReason): string;

implementation

function MakeStagePoint(X, Y: Double): TStagePoint;
begin
  Result.X := X;
  Result.Y := Y;
end;

procedure InitializeSpiralCursor(out Cursor: TStageSpiralCursor);
begin
  FillChar(Cursor, SizeOf(Cursor), 0);
  Cursor.LegLength := 1;
  Cursor.StepsRemaining := 1;
end;

function AdvanceSquareSpiral(var Cursor: TStageSpiralCursor): TStageGridPoint;
const
  DirectionX: array[0..3] of Integer = (1, 0, -1, 0);
  DirectionY: array[0..3] of Integer = (0, 1, 0, -1);
begin
  Inc(Cursor.GridX, DirectionX[Cursor.DirectionIndex]);
  Inc(Cursor.GridY, DirectionY[Cursor.DirectionIndex]);
  Dec(Cursor.StepsRemaining);

  if Cursor.StepsRemaining = 0 then
  begin
    Cursor.DirectionIndex := (Cursor.DirectionIndex + 1) mod 4;
    Inc(Cursor.LegsAtCurrentLength);
    if Cursor.LegsAtCurrentLength = 2 then
    begin
      Cursor.LegsAtCurrentLength := 0;
      Inc(Cursor.LegLength);
    end;
    Cursor.StepsRemaining := Cursor.LegLength;
  end;

  Result.X := Cursor.GridX;
  Result.Y := Cursor.GridY;
end;

function TryBuildStageSearchGeometry(const Settings: TStageSearchSettings;
  out Geometry: TStageSearchGeometry; out ErrorText: string): Boolean;
begin
  Result := False;
  ErrorText := '';
  FillChar(Geometry, SizeOf(Geometry), 0);

  if Settings.PixelSizeAngstrom <= 0 then
    ErrorText := 'Record pixel size must be greater than zero.'
  else if Settings.ImageWidthPixels <= 0 then
    ErrorText := 'Record image width must be a positive integer.'
  else if Settings.ImageHeightPixels <= 0 then
    ErrorText := 'Record image height must be a positive integer.'
  else if (Settings.SpeedFraction < 0.001) or
    (Settings.SpeedFraction > 1.0) then
    ErrorText := 'Stage speed must be between 0.1% and 100%.'
  else if Settings.MaxExtentUm <= 0 then
    ErrorText := 'Maximum X/Y extent must be greater than zero.';

  if ErrorText <> '' then
    Exit;

  Geometry.FovXUm := Settings.PixelSizeAngstrom *
    Settings.ImageWidthPixels / 10000.0;
  Geometry.FovYUm := Settings.PixelSizeAngstrom *
    Settings.ImageHeightPixels / 10000.0;
  Geometry.StrideXUm := Geometry.FovXUm * RECORD_SEARCH_STRIDE_FRACTION;
  Geometry.StrideYUm := Geometry.FovYUm * RECORD_SEARCH_STRIDE_FRACTION;
  Geometry.ChunkXUm := Geometry.FovXUm * RECORD_SEARCH_CHUNK_FRACTION;
  Geometry.ChunkYUm := Geometry.FovYUm * RECORD_SEARCH_CHUNK_FRACTION;

  if Geometry.StrideXUm > Settings.MaxExtentUm then
    ErrorText := 'The 75% Record X stride exceeds the maximum X/Y extent.'
  else if Geometry.StrideYUm > Settings.MaxExtentUm then
    ErrorText := 'The 75% Record Y stride exceeds the maximum X/Y extent.';

  Result := ErrorText = '';
end;

function StageSearchFinishReasonToString(Reason: TStageSearchFinishReason): string;
begin
  case Reason of
    sfrStopped: Result := 'Stopped by user';
    sfrBoundaryReached: Result := 'Maximum search extent reached';
    sfrHardwareLimit: Result := 'Stage hardware limit reached';
    sfrError: Result := 'Search error';
  else
    Result := 'Search finished';
  end;
end;

constructor TStageSearchThread.Create(AOwner: TStageSearchController;
  const Session: IStageMotionSession; const Settings: TStageSearchSettings;
  const Geometry: TStageSearchGeometry);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FSession := Session;
  FSettings := Settings;
  FGeometry := Geometry;
  FStopRequested := 0;
  FOrigin := MakeStagePoint(0, 0);
  FLastPosition := FOrigin;
end;

procedure TStageSearchThread.RequestStop;
begin
  InterlockedExchange(FStopRequested, 1);
end;

function TStageSearchThread.StopWasRequested: Boolean;
begin
  Result := InterlockedCompareExchange(FStopRequested, 0, 0) <> 0;
end;

function TStageSearchThread.PointWithinSearchBoundary(
  const Point: TStagePoint): Boolean;
begin
  Result := (Abs(Point.X - FOrigin.X) <= FSettings.MaxExtentUm + 1e-9) and
    (Abs(Point.Y - FOrigin.Y) <= FSettings.MaxExtentUm + 1e-9);
end;

function TStageSearchThread.PointWithinHardwareLimits(
  const Point: TStagePoint): Boolean;
begin
  Result := (Point.X >= FLimits.MinX) and (Point.X <= FLimits.MaxX) and
    (Point.Y >= FLimits.MinY) and (Point.Y <= FLimits.MaxY);
end;

procedure TStageSearchThread.QueueStarted;
var
  OriginCopy: TStagePoint;
  LimitsCopy: TStageLimits;
begin
  OriginCopy := FOrigin;
  LimitsCopy := FLimits;
  TThread.Queue(Self,
    procedure
    begin
      if FOwner <> nil then
        FOwner.DeliverStarted(OriginCopy, LimitsCopy);
    end);
end;

procedure TStageSearchThread.QueueProgress(Ring, GridX, GridY: Integer;
  const Position: TStagePoint);
var
  RingCopy: Integer;
  GridXCopy: Integer;
  GridYCopy: Integer;
  PositionCopy: TStagePoint;
begin
  RingCopy := Ring;
  GridXCopy := GridX;
  GridYCopy := GridY;
  PositionCopy := Position;
  TThread.Queue(Self,
    procedure
    begin
      if FOwner <> nil then
        FOwner.DeliverProgress(RingCopy, GridXCopy, GridYCopy, PositionCopy);
    end);
end;

procedure TStageSearchThread.QueueCompleted(Reason: TStageSearchFinishReason;
  const Detail: string; const Position: TStagePoint);
var
  ReasonCopy: TStageSearchFinishReason;
  DetailCopy: string;
  PositionCopy: TStagePoint;
begin
  ReasonCopy := Reason;
  DetailCopy := Detail;
  PositionCopy := Position;
  TThread.Queue(Self,
    procedure
    begin
      if FOwner <> nil then
        FOwner.DeliverCompleted(ReasonCopy, DetailCopy, PositionCopy);
    end);
end;

procedure TStageSearchThread.WaitForStageReady;
var
  StartTick: Cardinal;
begin
  StartTick := GetTickCount;
  while not FSession.IsReady do
  begin
    if GetTickCount - StartTick >= RECORD_SEARCH_MOVE_TIMEOUT_MS then
      raise Exception.Create('Timed out waiting for the stage to become ready.');
    Sleep(50);
  end;
end;

procedure TStageSearchThread.MoveAxisInChunks(Axis: TStageAxis;
  TargetUm, ChunkUm: Double);
var
  Current: TStagePoint;
  StartAxis: Double;
  Distance: Double;
  NextTarget: Double;
  Direction: Double;
  ChunkCount: Integer;
  ChunkIndex: Integer;
begin
  Current := FSession.GetPosition;
  FLastPosition := Current;
  if Axis = saX then
    StartAxis := Current.X
  else
    StartAxis := Current.Y;
  Distance := Abs(TargetUm - StartAxis);
  if Distance <= RECORD_SEARCH_POSITION_TOLERANCE_UM then
    Exit;

  if TargetUm > StartAxis then
    Direction := 1
  else
    Direction := -1;
  ChunkCount := Integer(Ceil(Distance / ChunkUm));

  for ChunkIndex := 1 to ChunkCount do
  begin
    if StopWasRequested then
      Exit;

    Current := FSession.GetPosition;
    FLastPosition := Current;
    NextTarget := StartAxis + Direction *
      Min(ChunkIndex * ChunkUm, Distance);

    if Axis = saX then
      Current.X := NextTarget
    else
      Current.Y := NextTarget;
    if not PointWithinSearchBoundary(Current) then
      raise EStageSearchBoundary.Create(
        'A submove would exceed the configured search extent.');
    if not PointWithinHardwareLimits(Current) then
      raise EStageHardwareLimit.Create(
        'A submove would exceed a stage hardware limit.');

    FSession.MoveAxisTo(Axis, NextTarget, FSettings.SpeedFraction);
    WaitForStageReady;
    FLastPosition := FSession.GetPosition;
  end;
end;

procedure TStageSearchThread.MoveToGridPoint(GridX, GridY: Integer);
var
  Target: TStagePoint;
begin
  Target.X := FOrigin.X + GridX * FGeometry.StrideXUm;
  Target.Y := FOrigin.Y + GridY * FGeometry.StrideYUm;

  if not PointWithinSearchBoundary(Target) then
    raise EStageSearchBoundary.Create(
      'The next grid point would exceed the configured X/Y extent.');
  if not PointWithinHardwareLimits(Target) then
    raise EStageHardwareLimit.Create(
      'The next grid point would exceed a reported stage XY limit.');

  if Abs(Target.X - FLastPosition.X) > RECORD_SEARCH_POSITION_TOLERANCE_UM then
    MoveAxisInChunks(saX, Target.X, FGeometry.ChunkXUm);
  if StopWasRequested then
    Exit;
  if Abs(Target.Y - FLastPosition.Y) > RECORD_SEARCH_POSITION_TOLERANCE_UM then
    MoveAxisInChunks(saY, Target.Y, FGeometry.ChunkYUm);
end;

procedure TStageSearchThread.Execute;
var
  Cursor: TStageSpiralCursor;
  GridPoint: TStageGridPoint;
  Ring: Integer;
  FinishReason: TStageSearchFinishReason;
  FinishDetail: string;
begin
  FinishReason := sfrError;
  FinishDetail := '';
  try
    FSession.Open;
    if not FSession.IsReady then
      raise Exception.Create('Stage is not ready to begin Record Search.');
    FOrigin := FSession.GetPosition;
    FLastPosition := FOrigin;
    FLimits := FSession.GetLimits;
    if not PointWithinHardwareLimits(FOrigin) then
      raise Exception.Create('Current stage position is outside the reported XY limits.');
    QueueStarted;

    InitializeSpiralCursor(Cursor);

    while not StopWasRequested do
    begin
      GridPoint := AdvanceSquareSpiral(Cursor);
      MoveToGridPoint(GridPoint.X, GridPoint.Y);
      if StopWasRequested then
        Break;
      FLastPosition := FSession.GetPosition;
      Ring := Max(Abs(GridPoint.X), Abs(GridPoint.Y));
      QueueProgress(Ring, GridPoint.X, GridPoint.Y, FLastPosition);
    end;

    FLastPosition := FSession.GetPosition;
    FinishReason := sfrStopped;
    FinishDetail := 'No further stage moves were issued after the active submove.';
  except
    on E: EStageSearchBoundary do
    begin
      FinishReason := sfrBoundaryReached;
      FinishDetail := E.Message;
      try
        FLastPosition := FSession.GetPosition;
      except
        { Preserve the last position that was read successfully. }
      end;
    end;
    on E: EStageHardwareLimit do
    begin
      FinishReason := sfrHardwareLimit;
      FinishDetail := E.Message;
      try
        FLastPosition := FSession.GetPosition;
      except
        { Preserve the last position that was read successfully. }
      end;
    end;
    on E: Exception do
    begin
      FinishReason := sfrError;
      FinishDetail := E.Message;
      try
        FLastPosition := FSession.GetPosition;
      except
        { Preserve the last position that was read successfully. }
      end;
    end;
  end;

  try
    FSession.Close;
  except
    on E: Exception do
    begin
      if FinishDetail <> '' then
        FinishDetail := FinishDetail + ' '
      else
        FinishDetail := '';
      FinishDetail := FinishDetail +
        'Could not close the stage session: ' + E.Message;
      FinishReason := sfrError;
    end;
  end;
  QueueCompleted(FinishReason, FinishDetail, FLastPosition);
end;

constructor TStageSearchController.Create;
begin
  inherited Create;
  FState := sssIdle;
end;

destructor TStageSearchController.Destroy;
begin
  FOnStarted := nil;
  FOnProgress := nil;
  FOnComplete := nil;
  if FThread <> nil then
  begin
    FThread.FOwner := nil;
    FThread.RequestStop;
    FThread.WaitFor;
    TThread.RemoveQueuedEvents(FThread);
    FreeAndNil(FThread);
  end;
  inherited Destroy;
end;

procedure TStageSearchController.ReleaseCompletedThread;
begin
  if FThread = nil then
    Exit;
  FThread.WaitFor;
  TThread.RemoveQueuedEvents(FThread);
  FreeAndNil(FThread);
end;

procedure TStageSearchController.Start(const Session: IStageMotionSession;
  const Settings: TStageSearchSettings;
  const Geometry: TStageSearchGeometry);
begin
  if Active then
    raise Exception.Create('Record Search is already running.');
  if Session = nil then
    raise Exception.Create('No stage motion session is available.');
  ReleaseCompletedThread;
  FState := sssRunning;
  FThread := TStageSearchThread.Create(Self, Session, Settings, Geometry);
  try
    FThread.Start;
  except
    FState := sssIdle;
    FreeAndNil(FThread);
    raise;
  end;
end;

procedure TStageSearchController.Stop;
begin
  if (FThread = nil) or (FState = sssIdle) then
    Exit;
  FState := sssStopping;
  FThread.RequestStop;
end;

function TStageSearchController.Active: Boolean;
begin
  Result := FState <> sssIdle;
end;

procedure TStageSearchController.DeliverStarted(const Origin: TStagePoint;
  const Limits: TStageLimits);
begin
  if Assigned(FOnStarted) then
    FOnStarted(Origin, Limits);
end;

procedure TStageSearchController.DeliverProgress(Ring, GridX, GridY: Integer;
  const Position: TStagePoint);
begin
  if Assigned(FOnProgress) then
    FOnProgress(Ring, GridX, GridY, Position);
end;

procedure TStageSearchController.DeliverCompleted(
  Reason: TStageSearchFinishReason; const Detail: string;
  const FinalPosition: TStagePoint);
begin
  if FThread <> nil then
    FThread.WaitFor;
  FState := sssIdle;
  if Assigned(FOnComplete) then
    FOnComplete(Reason, Detail, FinalPosition);
end;

end.
