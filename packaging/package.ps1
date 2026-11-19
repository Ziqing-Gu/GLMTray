param(
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Program,
    [Parameter(Mandatory)][string]$Compiler,
    [Parameter(Mandatory)][string]$Staging,
    [Parameter(Mandatory)][string]$Output
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if ((Get-Item -LiteralPath $Program).VersionInfo.ProductVersion -ne $Version) { throw 'Program version mismatch.' }
foreach ($dir in $Staging,$Output) { [void][IO.Directory]::CreateDirectory($dir) }
Copy-Item -LiteralPath $Program -Destination (Join-Path $Staging 'GLMTray.exe')
Copy-Item -LiteralPath "$root\docs\Install-ZH.md","$root\docs\Install-EN.md","$root\LICENSE" -Destination $Staging
& $Compiler /Qp "/DProductVersion=$Version" "/DPayloadDir=$Staging" "/DPackageDir=$Output" "$PSScriptRoot\GLMTray.iss"
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed.' }
