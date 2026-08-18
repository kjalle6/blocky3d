<#
.SYNOPSIS
Runs the project's validator scripts as a named set.

.DESCRIPTION
Every validator is its own SceneTree main, so running "the tests" means one
Godot launch per validator. A full pass is therefore expensive and, without a
scope, dominated by the six frozen prototype levels: their twelve validators
are roughly 60% of the wall time and cannot be affected by most changes.

Scopes:
  Current   - everything except the dedicated prototype level validators.
              The default, and the right choice for ordinary work.
  Prototype - only the level1-6 runtime and playthrough validators, which
              guard the frozen regression fixtures.
  All       - both. Use before a commit, and after any change to shared
              infrastructure such as the runner, GameRoot, or the level base.

Validators run through tools/run_godot_tool.ps1, which holds the exclusive
automation lock, so they run one at a time by design.
#>
[CmdletBinding()]
param(
    [ValidateSet('Current', 'Prototype', 'All')]
    [string]$Scope = 'Current',

    # Opt-in; see the note on -Headless in tools/run_godot_tool.ps1.
    [switch]$Headless
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run_godot_tool.ps1'
$prototypePattern = '^validate_level[1-6]_(runtime|playthrough)$'

$all = Get-ChildItem -LiteralPath $PSScriptRoot -Filter 'validate_*.gd' |
    Sort-Object Name
$selected = switch ($Scope) {
    'Prototype' { $all | Where-Object { $_.BaseName -match $prototypePattern } }
    'Current'   { $all | Where-Object { $_.BaseName -notmatch $prototypePattern } }
    default     { $all }
}

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
