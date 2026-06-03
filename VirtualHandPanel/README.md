# Virtual Hand Panel

Classic VCL Delphi implementation of a focused virtual hand panel for TEMScripting.

## Build

Open `VirtualHandPanel.dpr` in Delphi/RAD Studio on the microscope Windows machine.
The project references generated TEMScripting units that should be restored
locally from the microscope control environment:

- `..\titan-scripting-SDK\Delphi\Temscripting_TLB.pas`
- `..\titan-scripting-SDK\Delphi\TemscriptingEvents.pas`

These vendor files are intentionally excluded from source control. See
`..\VENDOR_DEPENDENCIES.md` before publishing the repository.

## Modes

- `Simulator`: launches without microscope access and keeps fake values in memory.
- `Live TEMScripting`: the default startup mode. Uses `CoInstrument.Create`,
  microscope optics/stage APIs, and user-button event sinks.
- `Compact`: toggled from the top bar. The window shrinks to a focused layout
  with connect/refresh, selected control, selected preset, jog arrows, beam-shift
  configuration, action buttons, and the status log. `Full` restores the
  previous window size.

## Keyboard Model

Select a control in the left list, then use arrow keys or the on-screen jog buttons.

- Scalar/index controls: `Up`/`Right` increase, `Down`/`Left` decrease.
- Vector controls: `Left`/`Right` adjust X, `Up`/`Down` adjust Y.
- Beam shift has a `BM`/`EFCCD` configuration selector.
  `EFCCD` is selected by default and sends the opposite X/Y command.
  `BM` sends the normal vector jog direction.

Step presets are editable per selected control.
The jog buttons change font color by selected preset: fine is green, medium is yellow, and coarse is red.

## Hotkeys

- Arrow keys jog the selected control using the fine step.
- `Shift` + arrow keys jog the selected control using the coarse step.
- `Shift+1`: fine step.
- `Shift+2`: medium step.
- `Shift+3`: coarse step.

## Action Buttons

The action panel sends literal backend commands:

- `Open Column Valves`: opens the microscope column valves.
- `Close Column Valves`: closes the microscope column valves.
- `Screen Lift`: sets the main screen to `spUp`.
- `Screen Down`: sets the main screen to `spDown`.
- `Reset Defocus`: calls `Projection.ResetDefocus`.
- `Eucentric Focus`: currently logs a request; the bundled TEMScripting type library does not expose a direct eucentric-focus method.
- `Spotsize -` / `Spotsize +`: adjusts `Illumination.SpotsizeIndex` within `1..11`.
