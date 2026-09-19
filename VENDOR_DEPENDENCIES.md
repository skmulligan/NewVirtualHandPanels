# Vendor Dependencies

This project depends on Thermo/FEI TEMScripting files that may be installed on microscope control machines or provided with the instrument software.

Do not commit or publish those files unless you have confirmed redistribution rights. The local checkout may contain files such as:

- TEMScripting generated Delphi units
- TEMScripting DLLs and type libraries
- vendor example projects
- simulator executables
- vendor PDF/CHM documentation

The Delphi project currently imports:

```pascal
TEMScriptingEvents in '..\titan-scripting-SDK\Delphi\TemscriptingEvents.pas',
TemScripting_TLB in '..\titan-scripting-SDK\Delphi\Temscripting_TLB.pas';
```

For local builds, restore those files from the microscope control environment into the expected relative path, or update `VirtualHandPanel/VirtualHandPanel.dpr` to point at your local SDK location.

## Multifunction knob adapter

Context-sensitive MF-X and MF-Y input uses the microscope-installed 32-bit COM
server with ProgID `adaFsKnob.adaFsKnob`. On the Titan system inspected during
development it is registered at:

```text
C:\Titan\Adapters\adafsknob.dll
CLSID {CB486022-7E31-11D2-8E4A-006094AE5A81}
```

The application uses late-bound automation calls (`Init`, `SimulatePulse`, and
`Close`), so the vendor type-library import is not required at build time. The
DLL and its FEI dependencies must remain installed and registered by the
microscope software. Build `VirtualHandPanel` as Win32; do not redistribute or
re-register the vendor DLL without vendor authorization.
