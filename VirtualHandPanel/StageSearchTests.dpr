program StageSearchTests;

{$APPTYPE CONSOLE}

uses
  System.SysUtils,
  System.Math,
  StageSearch in 'StageSearch.pas';

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckNear(Expected, Actual: Double; const MessageText: string);
begin
  if Abs(Expected - Actual) > 1e-9 then
    raise Exception.CreateFmt('%s: expected %.12f, got %.12f',
      [MessageText, Expected, Actual]);
end;

procedure TestK3Geometry;
var
  Settings: TStageSearchSettings;
  Geometry: TStageSearchGeometry;
  ErrorText: string;
begin
  Settings.PixelSizeAngstrom := 1;
  Settings.ImageWidthPixels := 5760;
  Settings.ImageHeightPixels := 4092;
  Settings.SpeedFraction := 0.10;
  Settings.MaxExtentUm := 10;
  Check(TryBuildStageSearchGeometry(Settings, Geometry, ErrorText), ErrorText);
  CheckNear(0.576, Geometry.FovXUm, 'K3 FOV X');
  CheckNear(0.4092, Geometry.FovYUm, 'K3 FOV Y');
  CheckNear(0.432, Geometry.StrideXUm, 'K3 stride X');
  CheckNear(0.3069, Geometry.StrideYUm, 'K3 stride Y');
  CheckNear(0.0576, Geometry.ChunkXUm, 'K3 chunk X');
  CheckNear(0.04092, Geometry.ChunkYUm, 'K3 chunk Y');
  Check(Ceil(Geometry.StrideXUm / Geometry.ChunkXUm) = 8,
    'A 75% X stride must contain eight commands.');
  CheckNear(0.0288, Geometry.StrideXUm - 7 * Geometry.ChunkXUm,
    'The last X command must be 5% of the FOV.');
end;

procedure TestSpiralSequence;
const
  ExpectedX: array[1..9] of Integer = (1, 1, 0, -1, -1, -1, 0, 1, 2);
  ExpectedY: array[1..9] of Integer = (0, 1, 1, 1, 0, -1, -1, -1, -1);
var
  Cursor: TStageSpiralCursor;
  Point: TStageGridPoint;
  Index: Integer;
begin
  InitializeSpiralCursor(Cursor);
  for Index := 1 to 9 do
  begin
    Point := AdvanceSquareSpiral(Cursor);
    Check((Point.X = ExpectedX[Index]) and (Point.Y = ExpectedY[Index]),
      Format('Unexpected square-spiral point at index %d.', [Index]));
  end;
end;

procedure TestValidation;
var
  Settings: TStageSearchSettings;
  Geometry: TStageSearchGeometry;
  ErrorText: string;
begin
  Settings.PixelSizeAngstrom := 0;
  Settings.ImageWidthPixels := 5760;
  Settings.ImageHeightPixels := 4092;
  Settings.SpeedFraction := 0.10;
  Settings.MaxExtentUm := 10;
  Check(not TryBuildStageSearchGeometry(Settings, Geometry, ErrorText),
    'Zero pixel size must be rejected.');

  Settings.PixelSizeAngstrom := 100;
  Check(not TryBuildStageSearchGeometry(Settings, Geometry, ErrorText),
    'A stride larger than the configured extent must be rejected.');
end;

begin
  try
    TestK3Geometry;
    TestSpiralSequence;
    TestValidation;
    Writeln('StageSearch tests passed.');
  except
    on E: Exception do
    begin
      Writeln('StageSearch tests failed: ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.
