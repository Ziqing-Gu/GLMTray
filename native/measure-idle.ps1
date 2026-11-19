param([Parameter(Mandatory)][int]$ProcessId,[Parameter(Mandatory)][string]$Report,[int]$Seconds=60)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class TrayCycleProbe {
 [DllImport("kernel32.dll", SetLastError=true)] public static extern bool QueryProcessCycleTime(IntPtr process, out ulong cycles);
}
'@
$p = Get-Process -Id $ProcessId
$processors = [Environment]::ProcessorCount
function Read-CPU {
    $p.Refresh()
    if ($p.HasExited) { throw 'Helper exited during measurement' }
    $cycles = [UInt64]0
    if (![TrayCycleProbe]::QueryProcessCycleTime($p.Handle,[ref]$cycles)) { throw 'Cycle counter unavailable' }
    [pscustomobject]@{T=[Diagnostics.Stopwatch]::GetTimestamp();Ticks=$p.TotalProcessorTime.Ticks;Cycles=$cycles;WorkingSetBytes=$p.WorkingSet64;PrivateBytes=$p.PrivateMemorySize64}
}
$first = Read-CPU
$prev = $first
$rows = for ($i=0; $i -lt $Seconds; $i++) {
    Start-Sleep -Milliseconds 1000
    $next = Read-CPU
    $dt = ($next.T-$prev.T)/[double][Diagnostics.Stopwatch]::Frequency
    $percent = 100.0*($next.Ticks-$prev.Ticks)/10000000.0/$dt/$processors
    [pscustomobject]@{Seconds=$dt;CPUPercent=$percent;CycleDelta=$next.Cycles-$prev.Cycles}
    $prev = $next
}
$duration = ($prev.T-$first.T)/[double][Diagnostics.Stopwatch]::Frequency
$cpuTimeMs = ($prev.Ticks-$first.Ticks)/10000.0
$peak = ($rows.CPUPercent | Measure-Object -Maximum).Maximum
$result = [pscustomobject]@{Program=$p.Path;Pid=$p.Id;DurationSeconds=$duration;LogicalProcessors=$processors;CPUTimeMs=$cpuTimeMs;MeanPercent=100.0*$cpuTimeMs/1000.0/$duration/$processors;MaxIntervalPercent=$peak;IntervalsOverLimit=@($rows | Where-Object CPUPercent -gt 0.05).Count;CycleDelta=$prev.Cycles-$first.Cycles;WorkingSetMiB=$prev.WorkingSetBytes/1MB;PrivateCommitMiB=$prev.PrivateBytes/1MB;Samples=$rows}
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Report -Encoding utf8
$result | Select-Object * -ExcludeProperty Samples
if ($result.IntervalsOverLimit -gt 0) { throw 'At least one idle sampling interval exceeded 0.05%.' }
