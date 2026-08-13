[CmdletBinding()]
param(
    [switch]$Disable
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$dumpFolder = Join-Path $projectRoot 'build\crash_dumps'
$executableName = 'Godot_v4.6.3-stable_win64.exe'
$registryPath = (
    'HKCU:\Software\Microsoft\Windows\Windows Error Reporting\LocalDumps\' +
    $executableName
)

if ($Disable) {
    if (Test-Path -LiteralPath $registryPath) {
        Remove-Item -LiteralPath $registryPath -Recurse -Force
    }
    Write-Host "Crash dumps disabled for $executableName"
    exit 0
}

New-Item -ItemType Directory -Path $dumpFolder -Force | Out-Null
New-Item -Path $registryPath -Force | Out-Null
New-ItemProperty `
    -Path $registryPath `
    -Name DumpFolder `
    -PropertyType ExpandString `
    -Value $dumpFolder `
    -Force | Out-Null
New-ItemProperty `
    -Path $registryPath `
    -Name DumpType `
    -PropertyType DWord `
    -Value 2 `
    -Force | Out-Null
New-ItemProperty `
    -Path $registryPath `
    -Name DumpCount `
    -PropertyType DWord `
    -Value 2 `
    -Force | Out-Null

Write-Host "Full crash dumps enabled for $executableName"
Write-Host "Folder: $dumpFolder"
Write-Host 'Retention: 2 dumps'
