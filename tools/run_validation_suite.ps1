<#
.SYNOPSIS
Runs the project's validator scripts as a named set.

.DESCRIPTION
Every validator is its own SceneTree main, so running "the tests" means one
Godot launch per validator. Runs every current validator. The scope switch is
kept because a slower set will almost certainly reappear; before the six
prototype levels and their twelve dedicated validators were deleted, they were
that set and accounted for roughly 60% of a full run.

Validators run through tools/run_godot_tool.ps1, which holds the exclusive
automation lock, so they run one at a time by design.
#>
[CmdletBinding()]
param(
    [ValidateSet('All')]
    [string]$Scope = 'All',

    # Opt-in; see the note on -Headless in tools/run_godot_tool.ps1.
    [switch]$Headless
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run_godot_tool.ps1'
$all = Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'validate_*.gd' |
    Sort-Object Name
$selected = $all

if (@($selected).Count -eq 0) {
    throw "No validators matched scope '$Scope'."
}

Write-Host ("Running {0} validator(s), scope {1}{2}." -f `
    @($selected).Count, $Scope, $(if ($Headless) { ', headless' } else { '' }))

$failures = @()
$started = Get-Date
foreach ($file in $selected) {
    $runStarted = Get-Date
    if ($Headless) {
        & $runner -Headless -Script ("res://tools/" + $file.Name) > $null 2>&1
    } else {
        & $runner -Script ("res://tools/" + $file.Name) > $null 2>&1
    }
    $code = $LASTEXITCODE
    $elapsed = ((Get-Date) - $runStarted).TotalSeconds
    if ($code -eq 0) {
        Write-Host ("  {0,-52} PASS  {1,5:N1}s" -f $file.BaseName, $elapsed)
    } else {
        Write-Host ("  {0,-52} FAIL({1}) {2,5:N1}s" -f $file.BaseName, $code, $elapsed)
        $failures += $file.BaseName
    }
}

$total = ((Get-Date) - $started).TotalSeconds
if ($failures.Count -gt 0) {
    Write-Host ""
    [Console]::Error.WriteLine(
        ("{0} of {1} validator(s) failed in {2:N1}s: {3}" -f `
            $failures.Count, @($selected).Count, $total, ($failures -join ', '))
    )
    exit 1
}
Write-Host ""
Write-Host ("All {0} validator(s) passed in {1:N1}s." -f @($selected).Count, $total)
exit 0
