param([Parameter(Mandatory)][string]$BuildDirectory)
$ErrorActionPreference = 'Stop'
$testRoot = (Join-Path $BuildDirectory 'test')
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$testExe = (Join-Path $BuildDirectory 'GLMTrayTest.exe')
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TrayNativeProbe {
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr window);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr window);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string className, string title);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern bool PostMessage(IntPtr window, uint message, UIntPtr wparam, IntPtr lparam);
}
'@
$checks = [System.Collections.Generic.List[string]]::new()
$fixture = $null
$helper = $null
function Wait-Condition([scriptblock]$Condition, [string]$Label, [int]$TimeoutMs = 6000) {
    $waitClock = [Diagnostics.Stopwatch]::StartNew()
    while ($waitClock.ElapsedMilliseconds -lt $TimeoutMs) {
        if (& $Condition) { $checks.Add($Label); return }
        Start-Sleep -Milliseconds 100
    }
    throw "Failed: $Label"
}
function Invoke-Control([string]$Command) {
    $request = Start-Process -FilePath $testExe -ArgumentList $Command -WindowStyle Hidden -PassThru -Wait
    if ($request.ExitCode -ne 0) { throw "Control failed: $Command" }
}
function Send-Fixture([int]$Action) {
    $fixtureWindow = [TrayNativeProbe]::FindWindow('GLMTray.TestFixture','GLM  5.2.0 [ native self test ]')
    if ($fixtureWindow -eq [IntPtr]::Zero) { throw 'Fixture window missing.' }
    if (![TrayNativeProbe]::PostMessage($fixtureWindow, 0x8014, [UIntPtr]$Action, [IntPtr]::Zero)) { throw 'Fixture command failed.' }
}
try {
    $helper = Start-Process -FilePath $testExe -ArgumentList '--autostart' -WindowStyle Hidden -PassThru
    Wait-Condition { [TrayNativeProbe]::FindWindow('GLMTray.Test.Controller','GLM Tray Controller') -ne [IntPtr]::Zero } 'Helper created hidden controller'
    $fixture = Start-Process -FilePath $testExe -ArgumentList '--fixture' -WindowStyle Hidden -PassThru
    Wait-Condition { [TrayNativeProbe]::FindWindow('GLMTray.TestFixture','GLM  5.2.0 [ native self test ]') -ne [IntPtr]::Zero } 'Late main-window title discovered'
    $fixtureWindow = [TrayNativeProbe]::FindWindow('GLMTray.TestFixture','GLM  5.2.0 [ native self test ]')
    Wait-Condition { ![TrayNativeProbe]::IsWindowVisible($fixtureWindow) } 'New-process window hidden without polling'
    Invoke-Control '--show'
    Wait-Condition { [TrayNativeProbe]::IsWindowVisible($fixtureWindow) } 'IPC show restores hidden window'
    Send-Fixture 2
    Wait-Condition { ![TrayNativeProbe]::IsWindowVisible($fixtureWindow) } 'Minimize event hides immediately'
    Invoke-Control '--show'
    Wait-Condition { [TrayNativeProbe]::IsWindowVisible($fixtureWindow) -and ![TrayNativeProbe]::IsIconic($fixtureWindow) } 'Show restores minimized window'
    Send-Fixture 3
    Wait-Condition { [TrayNativeProbe]::FindWindow('STATIC','MIDI Settings Test') -ne [IntPtr]::Zero } 'Modal fixture opened'
    Invoke-Control '--hide'
    Start-Sleep -Milliseconds 300
    if (![TrayNativeProbe]::IsWindowVisible($fixtureWindow)) { throw 'Dialog protection failed.' }
    $checks.Add('Hide refuses active modal dialog')
    Send-Fixture 4
    Invoke-Control '--hide'
    Wait-Condition { ![TrayNativeProbe]::IsWindowVisible($fixtureWindow) } 'Hide works after dialog closes'
    $second = Start-Process -FilePath $testExe -WindowStyle Hidden -PassThru -Wait
    if ($second.ExitCode -ne 0) { throw 'Second launch failed.' }
    Wait-Condition { [TrayNativeProbe]::IsWindowVisible($fixtureWindow) } 'Second launch shows existing instance'
    Invoke-Control '--hide'
    Wait-Condition { ![TrayNativeProbe]::IsWindowVisible($fixtureWindow) } 'Target hidden before exit-recovery check'
    Invoke-Control '--exit'
    if (!$helper.WaitForExit(5000)) { throw 'Exit failed.' }
    if (![TrayNativeProbe]::IsWindowVisible($fixtureWindow)) { throw 'Exit did not restore fixture.' }
    $checks.Add('Exit preserves and restores target process')
    Send-Fixture 3
    Wait-Condition { [TrayNativeProbe]::FindWindow('STATIC','MIDI Settings Test') -ne [IntPtr]::Zero } 'Dialog open before helper attaches'
    $helper = Start-Process -FilePath $testExe -ArgumentList '--autostart' -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 2200
    if (![TrayNativeProbe]::IsWindowVisible($fixtureWindow)) { throw 'Startup hid modal owner.' }
    $checks.Add('Startup deferred while dialog was open')
    Send-Fixture 4
    Wait-Condition { ![TrayNativeProbe]::IsWindowVisible($fixtureWindow) } 'Attach to already-running GLM'
    Send-Fixture 5
    if (!$fixture.WaitForExit(5000)) { throw 'Fixture close failed.' }
    $fixture = Start-Process -FilePath $testExe -ArgumentList '--fixture' -WindowStyle Hidden -PassThru
    Wait-Condition { [TrayNativeProbe]::FindWindow('GLMTray.TestFixture','GLM  5.2.0 [ native self test ]') -ne [IntPtr]::Zero } 'Replacement process creates new main window'
    $fixtureWindow = [TrayNativeProbe]::FindWindow('GLMTray.TestFixture','GLM  5.2.0 [ native self test ]')
    Wait-Condition { ![TrayNativeProbe]::IsWindowVisible($fixtureWindow) } 'Process-exit event re-arms startup discovery'
    Invoke-Control '--exit'
    if (!$helper.WaitForExit(5000)) { throw 'Final exit failed.' }
    [pscustomobject]@{Passed=$true;Checks=$checks} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$testRoot\functional-results.json" -Encoding utf8
    $checks
} catch {
    [pscustomobject]@{Passed=$false;Checks=$checks;Error=$_.ToString()} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath "$testRoot\functional-results.json" -Encoding utf8
    throw
} finally {
    Invoke-Control '--exit'
    if ([TrayNativeProbe]::FindWindow('GLMTray.TestFixture','GLM  5.2.0 [ native self test ]') -ne [IntPtr]::Zero) { Send-Fixture 5 }
}
