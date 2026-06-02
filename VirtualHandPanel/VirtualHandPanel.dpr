program VirtualHandPanel;

uses
  Vcl.Forms,
  MainForm in 'MainForm.pas' {frmMain},
  PanelTypes in 'PanelTypes.pas',
  MicroscopeBackend in 'MicroscopeBackend.pas',
  SimulatorBackend in 'SimulatorBackend.pas',
  LiveBackend in 'LiveBackend.pas',
  TEMScriptingEvents in '..\titan-scripting-krios1\Delphi\TemscriptingEvents.pas',
  TemScripting_TLB in '..\titan-scripting-krios1\Delphi\Temscripting_TLB.pas';

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.Title := 'Virtual Hand Panel';
  Application.CreateForm(TMainForm, frmMain);
  Application.Run;
end.
