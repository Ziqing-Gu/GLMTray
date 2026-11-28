param(
    [Parameter(Mandatory)] [string]$BuildDirectory,
    [Parameter(Mandatory)] [string]$Compiler,
    [Parameter(Mandatory)] [string]$LegacyInstallerScript,
    [Parameter(Mandatory)] [string]$LegacyPayload
)
$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$family = 'GLMQA' + [guid]::NewGuid().ToString('N').Substring(0,8)
$root = Join-Path $BuildDirectory $family
$qaPayload = Join-Path $root 'payload'
$oldDir = Join-Path $root 'A 音乐 & Room'
$newDir = Join-Path $root 'B 监听 & Room'
$portableDir = Join-Path $root 'Portable'
$desktopTest = Join-Path ([Environment]::GetFolderPath('Desktop')) $family
$startTest = Join-Path ([Environment]::GetFolderPath('Programs')) $family
$regRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
$taskName = 'GLM Tray Test - ' + [System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$checks = [Collections.Generic.List[string]]::new()
$shortcuts = [Collections.Generic.List[string]]::new()
$shell = New-Object -ComObject WScript.Shell
$testTaskCreated = $false
$exeName = 'GLMTray.exe'

function Check($Condition, [string]$Label) {
    if (!$Condition) { throw $Label }
    $checks.Add($Label)
}
function Run([string]$Program, [string]$Arguments, [int]$Expected = 0) {
    $p = Start-Process -FilePath $Program -ArgumentList $Arguments -WindowStyle Hidden -PassThru
    if (!$p.WaitForExit(90000)) { throw "Timed out waiting for $Program" }
    if ($p.ExitCode -ne $Expected) { throw "$Program $Arguments returned $($p.ExitCode), expected $Expected" }
}
function Install([string]$Program, [string]$Label, [string]$Extra = '') {
    Run $Program ('/VERYSILENT /SUPPRESSMSGBOXES /SP- /NORESTART /LOG="' + (Join-Path $root "$Label.log") + '" ' + $Extra)
}
function Entries {
    @(Get-ChildItem -LiteralPath $regRoot | Where-Object PSChildName -like "$family-*" | Get-ItemProperty)
}
function Wait-Instance([string]$Path) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    do {
        $p = @(Get-Process -Name GLMTray -ErrorAction SilentlyContinue | Where-Object Path -eq $Path)
        if ($p.Count -eq 1) { return $true }
        Start-Sleep -Milliseconds 150
    } while ($timer.Elapsed.TotalSeconds -lt 7)
    return $false
}
function Link([string]$Name, [string]$Target, [string]$ArgsText) {
    $l = $shell.CreateShortcut($Name)
    $l.TargetPath = $Target
    $l.WorkingDirectory = Split-Path $Target -Parent
    $l.Arguments = $ArgsText
    $l.IconLocation = "$Target,0"
    $l.Description = 'GLM upgrade test'
    $l.Save()
    $shortcuts.Add($Name)
}

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) { throw 'A test logon task is already in use.' }
if ((Get-Item -LiteralPath (Join-Path $LegacyPayload $exeName)).VersionInfo.ProductVersion -ne '1.0.3') {
    throw 'Supply the verified 1.0.3 payload.'
}
$oldCompiled = Join-Path $root 'legacy'
$newCompiled = Join-Path $root 'current'
foreach ($dir in $oldCompiled,$newCompiled,$qaPayload) { [void][IO.Directory]::CreateDirectory($dir) }
$oldScript = Join-Path $oldCompiled 'legacy.iss'
$oldText = [IO.File]::ReadAllText($LegacyInstallerScript)
$oldText = $oldText.Replace('AppId=GLMTray-{#ProductVersion}-x64', 'AppId=' + $family + '-{#ProductVersion}-x64')
if (!$oldText.Contains("AppId=$family-")) { throw 'Legacy identity replacement failed.' }
$oldText = $oldText.Replace('SetupIconFile=..\native\GLMTray.ico', 'SetupIconFile=' + (Join-Path $source 'native\GLMTray.ico'))
[IO.File]::WriteAllText($oldScript,$oldText)
& $Compiler /Qp /DProductVersion=1.0.3 "/DPayloadDir=$LegacyPayload" "/DPackageDir=$oldCompiled" $oldScript
if ($LASTEXITCODE) { throw 'Legacy test installer compilation failed.' }
Copy-Item -LiteralPath (Join-Path $BuildDirectory 'build\GLMTrayTest.exe') -Destination (Join-Path $qaPayload $exeName)
foreach ($file in 'Install-ZH.md','Install-EN.md','GLMTray-Quick-Start.txt') {
    Copy-Item -LiteralPath (Join-Path $source "docs\$file") -Destination $qaPayload
}
Copy-Item -LiteralPath (Join-Path $source 'LICENSE') -Destination $qaPayload
& $Compiler /Qp /DProductVersion=1.0.5 "/DProductFamily=$family" "/DPayloadDir=$qaPayload" "/DPackageDir=$newCompiled" (Join-Path $PSScriptRoot 'GLMTray.iss')
if ($LASTEXITCODE) { throw 'Current test installer compilation failed.' }
$oldSetup = Join-Path $oldCompiled 'GLMTray-1.0.3-Windows-x64-Setup.exe'
$newSetup = Join-Path $newCompiled 'GLMTray-1.0.5-Windows-x64-Setup.exe'
$oldExe = Join-Path $oldDir $exeName
$newExe = Join-Path $newDir $exeName
try {
    Install $oldSetup '01-original' ('/DIR="' + $oldDir + '"')
    Check (@(Entries).Count -eq 1 -and (Test-Path -LiteralPath $oldExe)) 'Real legacy installer registration and original folder'
    $userFile = Join-Path $oldDir 'user-owned.txt'
    [IO.File]::WriteAllText($userFile,'preserve')
    $ini = "[GLMTray]" + [Environment]::NewLine + "HideOnMinimize=0" + [Environment]::NewLine + "GLMPath=..\custom\GLMv5.exe"
    [IO.File]::WriteAllText((Join-Path $oldDir 'GLMTray.ini'),$ini,[Text.Encoding]::Unicode)
    foreach ($dir in $desktopTest,$startTest) { [void][IO.Directory]::CreateDirectory($dir) }
    $desktopLink = Join-Path $desktopTest 'GLM 托盘助手.lnk'
    $startLink = Join-Path $startTest 'GLM 托盘助手.lnk'
    $unrelated = Join-Path $desktopTest 'Unrelated.lnk'
    Link $desktopLink $oldExe ''
    Link $startLink $oldExe '--show'
    Link $unrelated (Join-Path $env:windir 'System32\notepad.exe') ''
    $unrelatedHash = (Get-FileHash -LiteralPath $unrelated).Hash

    Install $newSetup '02-keep-directory'
    $rows = @(Entries)
    Check ($rows.Count -eq 1 -and $rows[0].DisplayVersion -eq '1.0.5' -and $rows[0].InstallLocation.TrimEnd('\') -eq $oldDir) 'Default upgrade reuses the selected legacy directory and its single uninstall record'
    Check ((Get-FileHash -LiteralPath $oldExe).Hash -eq (Get-FileHash -LiteralPath (Join-Path $qaPayload $exeName)).Hash) 'Updated helper payload verified'
    Check ($shell.CreateShortcut($startLink).TargetPath -eq $oldExe -and $shell.CreateShortcut($desktopLink).TargetPath -eq $oldExe) 'Existing shortcut paths survive an in-place upgrade'
    Check ([IO.File]::ReadAllText((Join-Path $oldDir 'GLMTray.ini')) -eq $ini) 'In-place preferences preserved'
    Run $oldExe '--enable-startup'
    $testTaskCreated = $true
    Start-ScheduledTask -TaskName $taskName
    Check (Wait-Instance $oldExe) 'Isolated sign-in task starts the previous path'

    Install $newSetup '03-portable' ('/PORTABLE=1 /DIR="' + $portableDir + '"')
    Check (@(Entries).Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $portableDir $exeName)) -and (Get-ScheduledTask -TaskName $taskName).Actions.Execute -eq $oldExe) 'Portable extraction leaves the installed copy and task alone'

    Install $newSetup '04-relocate' ('/DIR="' + $newDir + '"')
    $rows = @(Entries)
    Check ($rows.Count -eq 1 -and $rows[0].InstallLocation.TrimEnd('\') -eq $newDir -and !(Test-Path -LiteralPath $oldExe)) 'Relocation uninstalls the old executable and entry after installing the new copy'
    Check ((Get-Item -LiteralPath $newExe).VersionInfo.ProductVersion -eq '1.0.5' -and (Test-Path -LiteralPath (Join-Path $newDir 'GLMTray-Quick-Start.txt'))) 'New executable and quick guide installed'
    Check ((Test-Path -LiteralPath $userFile) -and (Test-Path -LiteralPath (Join-Path $oldDir 'GLMTray.ini'))) 'Original user files retained'
    $newIni = [IO.File]::ReadAllText((Join-Path $newDir 'GLMTray.ini'))
    $absolute = [IO.Path]::GetFullPath((Join-Path $oldDir '..\custom\GLMv5.exe'))
    Check ($newIni.Contains('HideOnMinimize=0') -and $newIni.Contains($absolute)) 'Relative GLM override and minimize preference preserved on move'
    foreach ($linkPath in $desktopLink,$startLink) {
        $l = $shell.CreateShortcut($linkPath)
        Check ($l.TargetPath -eq $newExe -and $l.WorkingDirectory -eq $newDir -and $l.IconLocation -eq "$newExe,0" -and $l.Description -eq 'GLM upgrade test') "Shortcut retargeted in place: $([IO.Path]::GetDirectoryName($linkPath))"
    }
    Check ($shell.CreateShortcut($startLink).Arguments -eq '--show' -and (Get-FileHash -LiteralPath $unrelated).Hash -eq $unrelatedHash) 'Shortcut arguments and unrelated links preserved'
    Check ((Get-ScheduledTask -TaskName $taskName).Actions.Execute -eq $newExe -and (Wait-Instance $newExe)) 'Moved running helper and single sign-in task target the new folder'
    Install $newSetup '05-repeat'
    $rows = @(Entries)
    Check ($rows.Count -eq 1 -and $rows[0].InstallLocation.TrimEnd('\') -eq $newDir -and (Wait-Instance $newExe)) 'Next default upgrade uses the new folder and restores the running helper'
    $uninstaller = $rows[0].UninstallString.Trim('"')
    if ((Split-Path $uninstaller -Parent) -ne $newDir) { throw 'Unexpected test uninstaller location.' }
    Run $uninstaller '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
    Check (@(Entries).Count -eq 0 -and !(Test-Path -LiteralPath $newExe) -and !(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) 'Uninstall removes only the test program, registration and own sign-in task'
    Check ((Test-Path -LiteralPath (Join-Path $newDir 'GLMTray.ini')) -and (Test-Path -LiteralPath $userFile)) 'Uninstall retains user-created data'
    $testTaskCreated = $false
    [pscustomobject]@{Passed=$true; Checks=$checks; Evidence=$root} | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $BuildDirectory 'upgrade-verified.json') -Encoding utf8
    $checks
} finally {
    if ($testTaskCreated) {
        $t = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        if ($t -and $t.Actions.Execute -in $oldExe,$newExe) {
            $helper = $t.Actions.Execute
            if (Test-Path -LiteralPath $helper) {
                Run $helper ('--setup-stop "' + $helper + '"')
                Run $helper '--disable-startup'
            }
        }
    }
    foreach ($entry in @(Entries)) {
        $uninstaller = $entry.UninstallString.Trim('"')
        $folder = [IO.Path]::GetFullPath((Split-Path $uninstaller -Parent))
        if ($folder -notin $oldDir,$newDir -or $entry.Publisher -ne 'Qing Audio') { throw 'Unexpected QA uninstall record.' }
        Run $uninstaller '/VERYSILENT /SUPPRESSMSGBOXES /NORESTART'
    }
    $pref = "HKCU:\Software\$family\Setup"
    if (Test-Path -LiteralPath $pref) { Remove-Item -LiteralPath $pref }
    $parent = "HKCU:\Software\$family"
    if ((Test-Path -LiteralPath $parent) -and (Get-Item -LiteralPath $parent).SubKeyCount -eq 0) { Remove-Item -LiteralPath $parent }
    foreach ($lnk in $shortcuts) { if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk } }
    foreach ($dir in $desktopTest,$startTest) { if ([IO.Directory]::Exists($dir)) { [IO.Directory]::Delete($dir, $false) } }
}
