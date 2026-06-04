# Hand Panels

Virtual hand-panel software with hotkeys for controlling selected Thermo/FEI TEMScripting microscope functions from a small Delphi VCL application.

The current app is `VirtualHandPanel`, a classic Windows/VCL implementation with two backend modes:

- `Simulator`: runs without microscope access and keeps fake microscope values in memory.
- `Live TEMScripting`: connects through TEMScripting COM APIs on a microscope control machine.

## Screenshots 

![Virtual HandPanel Screenshot](img/vhp-fullmini-screenshots.png)

## Modes

- `Live TEMScripting`: the default startup mode. Uses `CoInstrument.Create`,
  microscope optics/stage APIs, and user-button event sinks.
- `Compact`: toggled from the top bar. The window shrinks to a focused layout
  with connect/refresh, selected control, selected preset, jog arrows, beam-shift
  configuration, action buttons, and the status log. `Full` restores the
  previous window size.
- `Simulator`: launches without microscope access and keeps fake values in memory.

## Repository Contents

- `bin/` contains exe already compiled that can be run on microscope PC
- `VirtualHandPanel/`: Delphi source for the virtual hand panel.
- `VENDOR_DEPENDENCIES.md`: notes about external Thermo/FEI TEMScripting files that are required locally but should not be published.

## Hotkeys

- `← ↑ → ↓` Arrow keys jog the selected control using the fine step.
- `Shift + ← ↑ → ↓` jog the selected control using the coarse step.
- `Shift+1`: fine step.
- `Shift+2`: medium step.
- `Shift+3`: coarse step.

## Running

Download `bin/VirtualHandPanel.exe` to the microscope PC. Start the exe and with `Live TEMScripting` selected (default) press connect button.  Use buttons on program or keyboard hotkeys. 

The detailed control model and hotkeys are documented in `VirtualHandPanel/README.md`.

## Build

1. Install Delphi/RAD Studio on the Windows machine that will build the app.
2. Install or copy the TEMScripting SDK files from the microscope control environment.
3. Place the generated TEMScripting Delphi units at:

   ```text
   ../titan-scripting-SDK/Delphi/Temscripting_TLB.pas
   ../titan-scripting-SDK/Delphi/TemscriptingEvents.pas
   ```

   The path is relative to `VirtualHandPanel/VirtualHandPanel.dpr`.

4. Open `VirtualHandPanel/VirtualHandPanel.dpr` in Delphi/RAD Studio and build.

## License

MIT License
