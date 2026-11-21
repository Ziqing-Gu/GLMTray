// Only registered installations belonging to the current user participate in upgrades.
const
  UninstallRoot = 'Software\Microsoft\Windows\CurrentVersion\Uninstall\';
  PreferenceKey = 'Software\{#ProductFamily}\Setup';

type
  TInstalled = record
    Id, Dir, Uninstaller, Date: String;
    Version: Int64;
  end;

var
  Installs: array of TInstalled;
  Preferred: Integer;
  Scanned, ControlExtracted, RestartPending, KeepLogin, HadRunning, FinishFailed: Boolean;
  ChosenId, RestartFrom: String;

function OpenDirectory(Name: String; Access, Sharing, Security, Disposition,
  Flags, Template: LongWord): Integer;
  external 'CreateFileW@kernel32.dll stdcall';
function FinalPath(Handle: Integer; Buffer: String; Capacity, Flags: LongWord): LongWord;
  external 'GetFinalPathNameByHandleW@kernel32.dll stdcall';
function CloseDirectory(Handle: Integer): Boolean;
  external 'CloseHandle@kernel32.dll stdcall';
function NewTemporaryFile(Directory, Prefix: String; Unique: LongWord; Buffer: String): LongWord;
  external 'GetTempFileNameW@kernel32.dll stdcall';

function DirKey(Path: String): String;
var
  H: Integer;
  Buffer: String;
  Count: LongWord;
begin
  Result := RemoveBackslashUnlessRoot(ExpandFileName(Path));
  H := OpenDirectory(Result, 0, 7, 0, 3, $02000000, 0);
  if H <> -1 then begin
    try
      SetLength(Buffer, 32768);
      Count := FinalPath(H, Buffer, Length(Buffer), 0);
      if (Count > 0) and (Count < 32768) then begin
        SetLength(Buffer, Count);
        if Pos('\\?\UNC\', Buffer) = 1 then Buffer := '\\' + Copy(Buffer, 9, MaxInt)
        else if Pos('\\?\', Buffer) = 1 then Buffer := Copy(Buffer, 5, MaxInt);
        Result := RemoveBackslashUnlessRoot(Buffer);
      end;
    finally
      CloseDirectory(H);
    end;
  end;
  Result := Lowercase(Result);
end;

function SameDir(const Left, Right: String): Boolean;
begin
  Result := (Left <> '') and (Right <> '') and (DirKey(Left) = DirKey(Right));
end;

function ProgramAt(const Dir: String): String;
begin
  Result := AddBackslash(Dir) + 'GLMTray.exe';
end;

function ReadInstall(const Key: String; var Item: TInstalled): Boolean;
var
  Display, VersionText, Publisher, Directory, RegisteredDir, Cmd, ExeName: String;
begin
  Result := False;
  if (Pos(Lowercase('{#ProductFamily}-'), Lowercase(Key)) <> 1) or
     (CompareText(Copy(Key, Length(Key) - 3, 4), '_is1') <> 0) then Exit;
  if not RegQueryStringValue(HKCU64, UninstallRoot + Key, 'DisplayVersion', VersionText) or
     not StrToVersion(VersionText, Item.Version) or
     not RegQueryStringValue(HKCU64, UninstallRoot + Key, 'DisplayName', Display) or
     (Display <> 'GLM Tray ' + VersionText) or
     not RegQueryStringValue(HKCU64, UninstallRoot + Key, 'Publisher', Publisher) or
     (Publisher <> 'Qing Audio') then Exit;
  if not RegQueryStringValue(HKCU64, UninstallRoot + Key, 'InstallLocation', Directory) or
     not RegQueryStringValue(HKCU64, UninstallRoot + Key, 'Inno Setup: App Path', RegisteredDir) or
     (ExtractFileDrive(Directory) = '') or not SameDir(Directory, RegisteredDir) then Exit;
  if not RegQueryStringValue(HKCU64, UninstallRoot + Key, 'UninstallString', Cmd) then Exit;
  Cmd := RemoveQuotes(Trim(Cmd));
  ExeName := Lowercase(ExtractFileName(Cmd));
  if (Length(ExeName) <> 12) or (Copy(ExeName, 1, 5) <> 'unins') or
     (StrToIntDef(Copy(ExeName, 6, 3), -1) < 0) or (ExtractFileExt(ExeName) <> '.exe') or
     not SameDir(Directory, ExtractFileDir(Cmd)) then Exit;
  Item.Id := Copy(Key, 1, Length(Key) - 4);
  Item.Dir := RemoveBackslashUnlessRoot(Directory);
  Item.Uninstaller := Cmd;
  Item.Date := '';
  RegQueryStringValue(HKCU64, UninstallRoot + Key, 'InstallDate', Item.Date);
  Result := True;
end;

procedure Discover;
var
  Keys: TArrayOfString;
  I, N, SavedIndex: Integer;
  Saved: String;
  Item: TInstalled;
begin
  if Scanned then Exit;
  Scanned := True;
  Preferred := -1;
  SavedIndex := -1;
  RegQueryStringValue(HKCU64, PreferenceKey, 'LastDirectory', Saved);
  if RegGetSubkeyNames(HKCU64, RemoveBackslashUnlessRoot(UninstallRoot), Keys) then
    for I := 0 to GetArrayLength(Keys) - 1 do
      if ReadInstall(Keys[I], Item) then begin
        N := GetArrayLength(Installs);
        SetArrayLength(Installs, N + 1);
        Installs[N] := Item;
        if Preferred < 0 then Preferred := N
        else if (Item.Date > Installs[Preferred].Date) or
          ((Item.Date = Installs[Preferred].Date) and (Item.Version > Installs[Preferred].Version)) then Preferred := N;
        if SameDir(Saved, Item.Dir) then SavedIndex := N;
      end;
  if SavedIndex >= 0 then Preferred := SavedIndex;
end;

function DefaultInstallDirectory(Param: String): String;
var
  Saved: String;
begin
  if ExtractOnly then begin
    Result := ExpandConstant('{localappdata}\Programs\GLMTray\Portable');
    Exit;
  end;
  Discover;
  if Preferred >= 0 then Result := Installs[Preferred].Dir
  else if RegQueryStringValue(HKCU64, PreferenceKey, 'LastDirectory', Saved) and
          (ExtractFileDrive(Saved) <> '') then Result := Saved
  else Result := ExpandConstant('{localappdata}\Programs\GLM Tray');
end;

function SelectedAppId(Param: String): String;
begin
  Result := ChosenId;
end;

function RunAndWait(const FileName, Arguments: String): Integer;
var
  Code: Integer;
begin
  if not Exec(FileName, Arguments, '', SW_HIDE, ewWaitUntilTerminated, Code) then
    RaiseException(Format('Could not run %s (%d).', [FileName, Code]));
  Result := Code;
end;

function Control(const Command, Dir: String): Integer;
begin
  Result := RunAndWait(ExpandConstant('{tmp}\GLMTray.exe'), Command + ' "' + ProgramAt(Dir) + '"');
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  I, State, SameCount: Integer;
  Destination: String;
  TargetVersion: Int64;
begin
  Result := '';
  Discover;
  Destination := WizardDirValue;
  SameCount := 0;
  StrToVersion('{#ProductVersion}', TargetVersion);
  ChosenId := '{#ProductFamily}-x64-' + Copy(GetSHA256OfUnicodeString(DirKey(Destination)), 1, 24);
  for I := 0 to GetArrayLength(Installs) - 1 do begin
    if SameDir(Installs[I].Dir, Destination) then begin
      if ExtractOnly then begin Result := 'Choose a separate folder for portable extraction.'; Exit; end;
      SameCount := SameCount + 1;
      ChosenId := Installs[I].Id;
    end;
    if not ExtractOnly and (Installs[I].Version > TargetVersion) then begin
      Result := 'A newer GLM Tray version is already installed.'; Exit;
    end;
    if not ExtractOnly and not SameDir(Installs[I].Dir, Destination) and
       (not FileExists(Installs[I].Uninstaller) or not FileExists(ChangeFileExt(Installs[I].Uninstaller, '.dat'))) then begin
      Result := 'Repair the previous installation in its original folder before moving it: ' + Installs[I].Dir; Exit;
    end;
  end;
  if SameCount > 1 then begin
    Result := 'Several old uninstallers share this folder. Choose a new folder to consolidate these copies.'; Exit;
  end;
  if ExtractOnly then Exit;
  if (SameCount = 0) and FileExists(ProgramAt(Destination)) then begin
    Result := 'This folder contains an unregistered GLMTray.exe. Choose a separate installation folder.'; Exit;
  end;
  if not ControlExtracted then begin ExtractTemporaryFile('GLMTray.exe'); ControlExtracted := True; end;
  for I := 0 to GetArrayLength(Installs) - 1 do begin
    State := Control('--setup-state', Installs[I].Dir);
    if (State < 0) or (State > 3) then begin Result := 'Could not inspect ' + Installs[I].Dir; Exit; end;
    if (State and 2) <> 0 then KeepLogin := True;
    if (State and 1) <> 0 then begin
      RestartFrom := ProgramAt(Installs[I].Dir);
      if Control('--setup-stop', Installs[I].Dir) <> 0 then begin
        Result := 'Please exit the tray helper in ' + Installs[I].Dir + ' and retry.'; Exit;
      end;
      HadRunning := True;
      RestartPending := True;
    end;
  end;
end;

procedure CopyPreferences(const OldDir, NewDir: String);
var
  OldIni, NewIni, Staged, Configured, AbsPath: String;
begin
  OldIni := AddBackslash(OldDir) + 'GLMTray.ini';
  NewIni := AddBackslash(NewDir) + 'GLMTray.ini';
  if not FileExists(OldIni) or FileExists(NewIni) then Exit;
  SetLength(Staged, 32768);
  if NewTemporaryFile(NewDir, 'glm', 0, Staged) = 0 then RaiseException('Could not stage GLMTray.ini.');
  SetLength(Staged, Pos(#0, Staged) - 1);
  try
    if not CopyFile(OldIni, Staged, False) then RaiseException('Could not copy GLMTray.ini.');
    Configured := GetIniString('GLMTray', 'GLMPath', '', OldIni);
    if (Configured <> '') and (ExtractFileDrive(Configured) = '') then begin
      AbsPath := ExpandFileName(AddBackslash(OldDir) + Configured);
      if not SetIniString('GLMTray', 'GLMPath', AbsPath, Staged) or
         (GetIniString('GLMTray', 'GLMPath', '', Staged) <> AbsPath) then
        RaiseException('Could not preserve the relative GLM path in GLMTray.ini.');
    end;
    if not RenameFile(Staged, NewIni) and not FileExists(NewIni) then
      RaiseException('Could not save the migrated GLMTray.ini.');
  finally
    if FileExists(Staged) then DeleteFile(Staged);
  end;
end;

procedure UpdateLink(const Shell: Variant; const LinkName, OldDir, NewDir: String);
var
  Link: Variant;
  Target, Icon, IconFile, IconSuffix, Working: String;
  P: Integer;
begin
  try
    Link := Shell.CreateShortcut(LinkName);
    Target := Link.TargetPath;
  except
    Exit; { A shell/advertised shortcut may have no file-system target. }
  end;
  if (CompareText(ExtractFileName(Target), 'GLMTray.exe') <> 0) or
     not SameDir(ExtractFileDir(Target), OldDir) then Exit;
  Working := Link.WorkingDirectory;
  Icon := Link.IconLocation;
  P := Length(Icon);
  while (P > 0) and (Icon[P] <> ',') do P := P - 1;
  if P > 0 then begin IconFile := Copy(Icon, 1, P - 1); IconSuffix := Copy(Icon, P, MaxInt); end
  else begin IconFile := Icon; IconSuffix := ''; end;
  if CompareText(RemoveQuotes(Trim(IconFile)), Target) = 0 then Link.IconLocation := ProgramAt(NewDir) + IconSuffix;
  if SameDir(Working, OldDir) then Link.WorkingDirectory := NewDir;
  Link.TargetPath := ProgramAt(NewDir);
  Link.Save;
  Link := Shell.CreateShortcut(LinkName);
  Target := Link.TargetPath;
  if CompareText(Target, ProgramAt(NewDir)) <> 0 then RaiseException('Could not update shortcut: ' + LinkName);
end;

procedure UpdateLinksIn(const Shell: Variant; const Dir, OldDir, NewDir: String; Depth: Integer);
var
  F: TFindRec;
  Child: String;
begin
  if not FindFirst(AddBackslash(Dir) + '*', F) then Exit;
  try
    repeat
      if (F.Name <> '.') and (F.Name <> '..') then begin
        Child := AddBackslash(Dir) + F.Name;
        if (F.Attributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then begin
          if (Depth > 0) and ((F.Attributes and $400) = 0) then UpdateLinksIn(Shell, Child, OldDir, NewDir, Depth - 1);
        end else if CompareText(ExtractFileExt(F.Name), '.lnk') = 0 then UpdateLink(Shell, Child, OldDir, NewDir);
      end;
    until not FindNext(F);
  finally
    FindClose(F);
  end;
end;

procedure FinishUpgrade;
var
  I, ExitCode: Integer;
  Destination, InstalledExe: String;
  Shell: Variant;
  Current: TInstalled;
begin
  Destination := ExpandConstant('{app}');
  InstalledExe := ProgramAt(Destination);
  if GetSHA256OfFile(InstalledExe) <> GetSHA256OfFile(ExpandConstant('{tmp}\GLMTray.exe')) then
    RaiseException('Installed executable failed verification.');
  if Preferred >= 0 then
    if not SameDir(Installs[Preferred].Dir, Destination) then CopyPreferences(Installs[Preferred].Dir, Destination);
  if KeepLogin then
    if RunAndWait(InstalledExe, '--enable-startup') <> 0 then RaiseException('Could not migrate the sign-in task.');
  for I := 0 to GetArrayLength(Installs) - 1 do
    if not SameDir(Installs[I].Dir, Destination) then begin
      if VarIsEmpty(Shell) then Shell := CreateOleObject('WScript.Shell');
      UpdateLinksIn(Shell, ExpandConstant('{userdesktop}'), Installs[I].Dir, Destination, 1);
      UpdateLinksIn(Shell, ExpandConstant('{userprograms}'), Installs[I].Dir, Destination, 32);
    end;
  { Only retire the old installation after verifying its replacement and rebinding its entry points. }
  for I := 0 to GetArrayLength(Installs) - 1 do
    if not SameDir(Installs[I].Dir, Destination) then begin
      if not ReadInstall(Installs[I].Id + '_is1', Current) or
         (CompareText(Current.Uninstaller, Installs[I].Uninstaller) <> 0) then
        RaiseException('The previous registration changed during installation. Run Setup again.');
      ExitCode := RunAndWait(Current.Uninstaller, '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART');
      if (ExitCode <> 0) or RegKeyExists(HKCU64, UninstallRoot + Current.Id + '_is1') then
        RaiseException('Could not completely uninstall the previous copy in ' + Current.Dir);
    end;
  if not RegWriteStringValue(HKCU64, PreferenceKey, 'LastDirectory', Destination) then
    RaiseException('Could not save the chosen installation folder.');
  if RestartPending then begin
    RestartFrom := InstalledExe;
    if not Exec(InstalledExe, '--autostart', Destination, SW_HIDE, ewNoWait, ExitCode) then
      RaiseException('Could not restart the installed tray helper.');
    RestartPending := False;
  end;
end;

procedure CurStepChanged(Step: TSetupStep);
var
  Detail: String;
begin
  if (Step <> ssPostInstall) or ExtractOnly then Exit;
  try
    FinishUpgrade;
  except
    FinishFailed := True;
    Detail := GetExceptionMessage;
    Log('Migration incomplete: ' + Detail);
    SuppressibleMsgBox('GLM Tray installation needs attention:' + #13#10 + Detail, mbError, MB_OK, IDOK);
  end;
end;

function GetCustomSetupExitCode: Integer;
begin
  if FinishFailed then Result := 40 else Result := 0;
end;

function OfferStart: Boolean;
begin
  Result := not ExtractOnly and not HadRunning and not FinishFailed;
end;

procedure DeinitializeSetup;
var
  Code: Integer;
begin
  if RestartPending and FileExists(RestartFrom) then
    Exec(RestartFrom, '--autostart', ExtractFileDir(RestartFrom), SW_HIDE, ewNoWait, Code);
end;
