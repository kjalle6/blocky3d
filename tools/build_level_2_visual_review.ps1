[CmdletBinding()]
param(
    [switch]$SkipCapture
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$previewRoot = Join-Path $projectRoot 'build\previews\level_2_interior_opening'
$outputPath = Join-Path $previewRoot 'level_2_visual_review_sheet.png'
$runner = Join-Path $PSScriptRoot 'run_godot_tool.ps1'
$sheetBuilder = Join-Path $PSScriptRoot 'build_image_review_sheet.ps1'

if (-not $SkipCapture) {
    & powershell -ExecutionPolicy Bypass -File $runner `
        -Visual `
        -Script res://tools/capture_level_2_interior_opening.gd
    if ($LASTEXITCODE -ne 0) {
        throw "Level 2 visual capture failed with exit code $LASTEXITCODE."
    }
}

$beats = @(
    'route_overview',
    'route_overview_upper',
    '00_entry',
    '01_recap',
    '02_floating_ascent',
    '03_shaft_bottom',
    '04_shaft_middle',
    '05_top_left_end',
    '06_top_junction',
    '07_dash_crossing',
    '08_machine_run_up',
    '09_machine_low_route',
    '10_machine_high_route',
    '11_chamber_landing',
    '12_chamber_end',
    '13_dual_machine_run_up',
    '14_dual_machine_window',
    '15_dual_chamber_landing',
    '16_exit_gauntlet_run_up',
    '17_exit_gauntlet_crossing',
    '18_cave_lift_exit',
    '19_cave_lift_departure'
)
$reviewPaths = @()
foreach ($beat in $beats) {
    $reviewPaths += Join-Path $previewRoot "${beat}_clean.png"
    $reviewPaths += Join-Path $previewRoot "${beat}_diagnostic.png"
}

foreach ($path in $reviewPaths) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing Level 2 review frame: $path"
    }
}

& $sheetBuilder `
    -OutputPath $outputPath `
    -Columns 2 `
    -CellWidth 960 `
    -InputPaths $reviewPaths
if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw "Level 2 review-sheet build failed with exit code $LASTEXITCODE."
}
if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
    throw "Level 2 review-sheet builder did not create: $outputPath"
}

Write-Output "Level 2 visual review sheet: $outputPath"
