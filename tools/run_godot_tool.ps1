[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^res://tools/[A-Za-z0-9_./-]+\.gd$')]
    [string]$Script,

    [switch]$Visual,

    [switch]$CloseRunningGodot,

    [ValidateRange(320, 7680)]
    [int]$Width = 1920,

    [ValidateRange(240, 4320)]
    [int]$Height = 1080,

    [string]$GodotExecutable = (
        'D:\GodotTools\Godot_v4.6.3-stable_mono_win64\' +
        'Godot_v4.6.3-stable_mono_win64_console.exe'
    )
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$activeGodot = @(
    Get-Process -ErrorAction SilentlyContinue |
        Where-Object { $_.ProcessName -like 'Godot*' }
)

if ($CloseRunningGodot -and $activeGodot.Count -gt 0) {
    $processSummary = $activeGodot |
        Sort-Object StartTime |
        ForEach-Object {
            '{0} (PID {1}, started {2:HH:mm:ss})' -f `
                $_.ProcessName, $_.Id, $_.StartTime
        }
    Write-Host (
        @(
            'Closing active Godot processes before automation:'
            ($processSummary -join [Environment]::NewLine)
        ) -join [Environment]::NewLine
    )

    foreach ($process in $activeGodot) {
        if ($process.MainWindowHandle -ne 0) {
            $null = $process.CloseMainWindow()
        }
    }
    Start-Sleep -Milliseconds 1500

    # The console wrapper and editor/game children can finish or change PID
    # while shutdown is in progress. Refresh the set and tolerate a process
    # disappearing between enumeration and Stop-Process.
    for ($attempt = 0; $attempt -lt 4; $attempt += 1) {
        $remainingGodot = @(
            Get-Process -ErrorAction SilentlyContinue |
                Where-Object { $_.ProcessName -like 'Godot*' }
        )
        if ($remainingGodot.Count -eq 0) {
            break
        }
        foreach ($process in $remainingGodot) {
            try {
                Stop-Process -Id $process.Id -Force -ErrorAction Stop
            } catch {
                # A process that is already exiting may reject the stop request.
                # The refreshed check below decides whether shutdown succeeded.
            }
        }
        Start-Sleep -Milliseconds 500
    }

    $stillRunning = @(
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object { $_.ProcessName -like 'Godot*' }
    )
    if ($stillRunning.Count -gt 0) {
        [Console]::Error.WriteLine(
            'Could not close every Godot process; automation was not started.'
        )
        exit 2
    }
}

if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    [Console]::Error.WriteLine(
        "Godot executable was not found: $GodotExecutable"
    )
    exit 3
}

# Do not add --headless here. Godot 4.6.3 Mono reliably raises a native access
# violation in headless project-script runs on this machine, while the same
# scripts pass through the normal Compatibility renderer.
$arguments = @('--path', $projectRoot)
if ($Visual) {
    $arguments += @('--resolution', ('{0}x{1}' -f $Width, $Height))
}
$arguments += @('--script', $Script)

& $GodotExecutable @arguments
exit $LASTEXITCODE
