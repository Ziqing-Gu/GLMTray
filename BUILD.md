# Building GLM Tray

Use Windows x64, Visual Studio 2022 Build Tools with the x64 C++ toolchain, and a Windows SDK. From the source root, pass a writable, absolute build directory to `native\build-native.cmd`. The script locates the compiler with vswhere, compiles the resources and native helper, and builds a separate test executable. MSVC statically links its runtime.

Run `native\test-native.ps1 -BuildDirectory <build-directory>` to exercise the test helper with its own fixture and isolated IPC names. The production helper can report its GLM window with `GLMTray.exe --inspect <output-json>`. A running helper can be sampled with `native\measure-idle.ps1 -ProcessId <pid> -Report <output-json> -Seconds 120`.

Build the Windows installer with Inno Setup 6.7 or later using `packaging\package.ps1 -Version 1.0.2 -Program <helper-exe> -Compiler <ISCC.exe> -Staging <payload-directory> -Output <installer-output-directory>`. Use distinct staging, output and source directories. The package includes the production helper, both guides and the root license. To extract it without registering an uninstaller, run the installer with `/PORTABLE=1 /VERYSILENT /NORESTART /DIR="absolute-destination"`. Silent extraction does not launch GLM Tray.
