; ISCC /DProductVersion=1.0.2 /DPayloadDir=... /DPackageDir=... GLMTray.iss
#ifndef ProductVersion
  #error ProductVersion is required
#endif
#ifndef PayloadDir
  #error PayloadDir is required
#endif
#ifndef PackageDir
  #error PackageDir is required
#endif
[Setup]
AppId=GLMTray-{#ProductVersion}-x64
AppName=GLM Tray
AppVersion={#ProductVersion}
AppVerName=GLM Tray {#ProductVersion}
AppPublisher=Qing Audio
VersionInfoVersion={#ProductVersion}.0
VersionInfoProductVersion={#ProductVersion}
VersionInfoDescription=GLM Tray Windows x64 Setup
DefaultDirName={localappdata}\Programs\GLMTray\{#ProductVersion}
DisableDirPage=no
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#PackageDir}
OutputBaseFilename=GLMTray-{#ProductVersion}-Windows-x64-Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=no
RestartApplications=no
UninstallDisplayIcon={app}\GLMTray.exe
Uninstallable=not ExtractOnly
CreateUninstallRegKey=not ExtractOnly
UsePreviousAppDir=no
LicenseFile={#PayloadDir}\LICENSE
[Files]
Source: "{#PayloadDir}\GLMTray.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\Install-ZH.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\Install-EN.md"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#PayloadDir}\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
[Run]
Filename: "{app}\GLMTray.exe"; Parameters: "--autostart"; Description: "Start GLM Tray"; Flags: postinstall nowait skipifsilent unchecked
[UninstallRun]
Filename: "{app}\GLMTray.exe"; Parameters: "--disable-startup"; Flags: runhidden waituntilterminated skipifdoesntexist
[Code]
function ExtractOnly(): Boolean;
begin
  Result := ExpandConstant('{param:PORTABLE|0}') = '1';
end;
