@echo off
setlocal
if "%~1"=="" (
  echo Pass an absolute output directory as the first argument. 1>&2
  exit /b 2
)
set "outdir=%~f1"
if not exist "%outdir%\." mkdir "%outdir%"
if errorlevel 1 exit /b 1
set "src=%~dp0"
set "vsfind=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"

for /f "usebackq tokens=*" %%V in (`"%vsfind%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "vsroot=%%V"
if not defined vsroot exit /b 1
call "%vsroot%\VC\Auxiliary\Build\vcvars64.bat" >nul
if errorlevel 1 exit /b 1
pushd "%outdir%"
if errorlevel 1 exit /b 1
rc /nologo /i "%src%." /fo GLMTray.res "%src%GLMTray.rc"
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /O2 /W4 /WX /MT /utf-8 /c "%src%logon-task.cpp" /Fo:logon-task.obj
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /O2 /W4 /WX /MT /utf-8 /Fe:GLMTray.exe /Fo:GLMTray.obj "%src%GLMTray.cpp" GLMTray.res logon-task.obj /link /SUBSYSTEM:WINDOWS /DYNAMICBASE /NXCOMPAT
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /O2 /W4 /WX /MT /utf-8 /DGLMTRAY_TESTING /c "%src%logon-task.cpp" /Fo:logon-task-test.obj
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /EHsc /O2 /W4 /WX /MT /utf-8 /DGLMTRAY_TESTING /Fe:GLMTrayTest.exe /Fo:GLMTrayTest.obj "%src%GLMTray.cpp" GLMTray.res logon-task-test.obj /link /SUBSYSTEM:WINDOWS /DYNAMICBASE /NXCOMPAT
exit /b %errorlevel%
