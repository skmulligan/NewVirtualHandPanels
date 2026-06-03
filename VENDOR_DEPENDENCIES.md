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
