program VirtualHandPanel;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  HandPanelView in 'HandPanelView.pas',
  PanelSurfaceControl in 'PanelSurfaceControl.pas',
  PanelTypes in 'PanelTypes.pas',
  StageSearch in 'StageSearch.pas',
  MicroscopeBackend in 'MicroscopeBackend.pas',
  SimulatorBackend in 'SimulatorBackend.pas',
  LiveBackend in 'LiveBackend.pas',
  TEMScriptingEvents in '..\titan-scripting-SDK\Delphi\TemscriptingEvents.pas',
  TemScripting_TLB in '..\titan-scripting-SDK\Delphi\Temscripting_TLB.pas';

{$R 'VirtualHandPanel.res' 'VirtualHandPanel.rc'}
{$R 'HandPanelAssets.res'}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Virtual Hand Panel';
  Application.CreateForm(TMainForm, frmMain);
  Application.Run;
end.
