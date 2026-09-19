# Virtual Hand Panel

Classic VCL Delphi implementation of a focused virtual hand panel for TEMScripting.

## Build

Open `VirtualHandPanel.dpr` in Delphi/RAD Studio on the microscope Windows machine.
The project references generated TEMScripting units that should be restored
locally from the microscope control environment:

- `..\titan-scripting-SDK\Delphi\Temscripting_TLB.pas`
- `..\titan-scripting-SDK\Delphi\TemscriptingEvents.pas`

`StageSearchTests.dpr` is a separate console test project for Record FOV math,
input validation, and the initial square-spiral sequence. Build and run it with
the same Delphi compiler before rebuilding the main executable.

These vendor files are intentionally excluded from source control. See
`..\VENDOR_DEPENDENCIES.md` before publishing the repository.

The application icon is defined in `VirtualHandPanel.rc` and linked by the
resource directive in `VirtualHandPanel.dpr`. Delphi/RAD Studio compiles that
resource into `VirtualHandPanel.res` during the build; the generated `.res`
file is a build product and is intentionally not committed.

The hand-panel PNG is linked through the checked-in `HandPanelAssets.res`.
Keeping it separate prevents RAD Studio's application-resource generation from
replacing the background resource, and the checked-in file avoids requiring the
IDE to compile a secondary `.rc` file. If the PNG changes, regenerate the file
with `build_hand_panel_resource.py` or compile `HandPanelAssets.rc` with
`brcc32` on Windows.

If the resource is deliberately omitted, the program also looks for a file
named `HandPanelsBackground.png` beside `VirtualHandPanel.exe` at runtime.

Build the application for the **Win32** target. The microscope's
`adaFsKnob.adaFsKnob` COM adapter is an in-process 32-bit component and cannot
be loaded by a Win64 executable.

## Modes

- `Hand Panel`: the default large-format view. It uses the artwork in
  `..\img\Hand_panels.svg` as its design master and embeds
  `HandPanelsBackground.png` for dependency-free display on Windows 7. Circular
  controls use the original artwork as their face, with subtle hover, press,
  and keyboard-focus feedback. `Advanced` opens the
  detailed control, Record Search, and log view.
- `Simulator`: launches without microscope access and keeps fake values in memory.
- `Live TEMScripting`: the default startup mode. Uses `CoInstrument.Create`,
  microscope optics/stage APIs, and user-button event sinks.
- `Compact`: toggled from the top bar. The window shrinks to a focused layout
  with connect/refresh, selected control, selected preset, jog arrows, beam-shift
  configuration, action buttons, Record Search, and the status log. `Full` restores the
  previous window size.

## Multifunction knobs

The large Hand Panel view sends contextual MF-X and MF-Y pulses through the
microscope-installed `adaFsKnob.adaFsKnob` COM server. The live backend lazily
creates two adapters and initializes these model bindings:

```text
MdlBinding\MF x
MdlBinding\MF y
```

Use the **MF steps** selector in the top bar to choose **1**, **5**, or
**10 steps per click**. It starts at **5 steps (Medium)**; select **10 steps
(Coarse)** for larger adjustments. Click the left half of an X/Y knob to send
negative pulses, or the right half to send positive pulses. Small minus/plus
marks show each direction. The simulator logs the same pulse
requests without requiring the vendor adapter.

This selector shares the app's Fine/Medium/Coarse preset: changing it also
updates the Advanced and Compact preset selectors. The panel's Fine/Coarse
buttons and Shift+1/2/3 shortcuts update the MF steps selector too. It is
disabled while Record Search is active.

The Exposure, Stigmator, Dark Field, Diffraction, Wobbler, Eucentric Focus,
alpha/beta tilt, and Stage Z positions remain visible as disabled controls
with a muted slash. No microscope commands have been added for these positions.

## Integrated panel controls

- Intensity, MF-X, MF-Y, magnification, and focus use the existing drawn knob
  faces. A click sends one adjustment only when released inside the same half;
  dragging outside or across the center cancels it.
- Fine/Coarse and L1-L3/R1-R3 use the circles in the artwork. Selected Fine or
  Coarse buttons have a green outline on both panels.
- Tab moves focus between available controls. On a focused knob, Left/Down/minus
  decrease and Right/Up/plus increase. Space activates a focused round button.
  Commands occur on key release; holding a key does not repeat commands.
  Escape, lost focus, or disabling the control cancels a pending press.
- A focused panel control owns its direction keys, so it cannot accidentally
  jog the unrelated control selected in Advanced view. Shift+1/2/3 still select
  Fine/Medium/Coarse. Other keyboard jogging keeps its existing behavior.
- Artwork and hit areas scale from the same 1500 x 612 coordinates. Below 1000
  logical pixels in width, the panel scrolls instead of shrinking controls further.
- Record Search disables all panel commands until the search finishes.

The implementation is in `PanelSurfaceControl.pas` and `HandPanelView.pas`.
The existing PNG and embedded resource do not need regenerating for this style.

### Windows verification after rebuilding

Build `VirtualHandPanel.dpr` as Win32, then connect to Simulator. Check MF-X and
MF-Y in both directions at 1, 5, and 10 steps; the log must show exactly one
signed pulse request per click or key release. Check that dragging off a knob,
holding a key, and pressing Escape do not send extra commands. Verify Fine/Coarse
selection in both views, Tab/Space activation, and disabled controls during
Record Search. Resize the window and check alignment at 100%, 125%, and 150%
Windows display scaling before using the rebuilt application on the microscope.

## Record Search

Record Search supports the Record-to-View image-shift calibration workflow without
controlling SerialEM directly:

1. Start continuous Preview acquisition with the SerialEM Record preset.
2. Enter the Record pixel size in Angstroms per pixel. The image dimensions default
   to a full-frame K3 image (`5760 x 4092`) and remain editable for cropped or binned
   Record images.
3. Review the calculated field of view and 75% X/Y stride, then press `Start Search`
   and confirm the motion summary.
4. When the target feature is visible, press `Stop Search`. The stage stays at the
   last completed short submove instead of returning to the starting point.

The path starts to the right and continues up, left, and down as an outward square
spiral with leg lengths `1, 1, 2, 2, 3, 3...`. X and Y strides use 75% of the
corresponding Record dimension, giving 25% overlap when camera and stage axes align.
Each stride is divided into commands no larger than 10% of that frame dimension.

Defaults and safety behavior:

- Stage speed: 10% of normal TEMScripting speed, editable from 0.1% to 100%.
- Search extent: +/-10 um independently on X and Y.
- Hardware XY limits are read before motion and checked before every command.
- The stage must report ready before starting; each command has a 30-second ready timeout.
- Jogging, actions, refresh, and disconnect controls are disabled while searching.
- Closing the application requests Stop and waits for the active short submove.
- The simulator uses the same geometry and exposes the complete Start/Stop workflow.

The TEMScripting stage API has no command for aborting an active move. Stop therefore
prevents the next submove; it cannot interrupt the submove already sent to the stage.

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
