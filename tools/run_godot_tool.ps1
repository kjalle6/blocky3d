[CmdletBinding()]
param(
    [ValidatePattern('^res://tools/[A-Za-z0-9_./-]+\.gd$')]
    [string]$Script,

    [switch]$Visual,

    [switch]$Headless,

    [switch]$EditorImport,

    [switch]$Game,

    # Pack-only smoke exports use the same supervised standard engine.
    [ValidatePattern('^build/[A-Za-z0-9_./-]+\.pck$')]
    [string]$ExportPack,

    [ValidatePattern('^[A-Za-z0-9_-]+$')]
    [string]$ExportPreset = 'LayoutSmoke',

    [ValidatePattern('^build/[A-Za-z0-9_./-]+\.pck$')]
    [string]$MainPack,

    [switch]$CloseRunningGodot,

    [ValidateRange(320, 7680)]
    [int]$Width = 1920,

    [ValidateRange(240, 4320)]
    [int]$Height = 1080,

    [string]$GodotExecutable = (
        'D:\GodotTools\Godot_v4.6.3-stable_win64\' +
        'Godot_v4.6.3-stable_win64.exe'
    )
)

$ErrorActionPreference = 'Stop'

if ($ExportPack) {
    if ($EditorImport -or $Game -or $Visual -or $Script -or $MainPack) {
        throw '-ExportPack is a separate mode; it cannot be combined with other launch modes.'
    }
} elseif ($EditorImport) {
    if (-not [string]::IsNullOrWhiteSpace($Script)) {
        throw '-EditorImport cannot be combined with -Script.'
    }
    if ($Game) {
        throw '-EditorImport cannot be combined with -Game.'
    }
    if ($Visual) {
        throw '-EditorImport cannot be combined with -Visual.'
    }
} elseif ($Game) {
    if (-not [string]::IsNullOrWhiteSpace($Script)) {
        throw '-Game cannot be combined with -Script.'
    }
} elseif ([string]::IsNullOrWhiteSpace($Script)) {
    throw '-Script is required unless -EditorImport or -Game is used.'
}

if ($Headless) {
    # Opt-in only, and deliberately narrow. Headless was an early repeatable
    # trigger for this machine's native access violations; the root cause was
    # never proven, so it stays off by default and every headless run is
    # labelled in the log name. If native faults reappear, drop -Headless
    # first and see whether they stop.
    if ($EditorImport) {
        throw '-Headless cannot be combined with -EditorImport; --import has its own mode.'
    }
    if ($Game) {
        throw '-Headless cannot be combined with -Game; the game needs a window.'
    }
    if ($Visual) {
        throw '-Headless cannot be combined with -Visual; capture scripts must render.'
    }
}

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$resolvedPackPath = $null
if ($ExportPack -or $MainPack) {
    if ($MainPack -and ($EditorImport -or $ExportPack)) {
        throw '-MainPack is for a game or script run, not editor import/export.'
    }
    $packRelativePath = if ($ExportPack) { $ExportPack } else { $MainPack }
    $resolvedPackPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $packRelativePath))
    $packBuildPrefix = [System.IO.Path]::GetFullPath((Join-Path $projectRoot 'build')) + '\'
    if (-not $resolvedPackPath.StartsWith($packBuildPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'Pack paths must stay inside this project build directory.'
    }
    if ($MainPack -and -not (Test-Path -LiteralPath $resolvedPackPath -PathType Leaf)) {
        throw 'The requested main pack does not exist.'
    }
    if ($ExportPack) {
        New-Item -ItemType Directory -Path ([System.IO.Path]::GetDirectoryName($resolvedPackPath)) -Force | Out-Null
    }
}
$automationProfileRoot = Join-Path $projectRoot 'build\godot_automation_profile'
$automationRoamingRoot = Join-Path $automationProfileRoot 'Roaming'
$automationLocalRoot = Join-Path $automationProfileRoot 'Local'
$pathSeparators = [char[]]@(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$projectPrefix = $projectRoot.TrimEnd($pathSeparators) + `
    [System.IO.Path]::DirectorySeparatorChar
$resolvedAutomationProfile = [System.IO.Path]::GetFullPath(
    $automationProfileRoot
)
if (-not $resolvedAutomationProfile.StartsWith(
        $projectPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
)) {
    throw "Refusing to place the Godot automation profile outside the project: $resolvedAutomationProfile"
}

# Codex automation runs in a restricted process that cannot write to the
# interactive Windows profile. Godot normally places editor caches and
# `user://` below APPDATA/LOCALAPPDATA; denied writes there have produced both
# clear editor errors and keep automation away from the interactive profile.
# Give only the wrapper process a project-local, gitignored profile instead.
# The normal editor is unaffected, and validators cannot touch the player's
# real campaign save.
foreach ($directory in @($automationRoamingRoot, $automationLocalRoot)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

# Prevent two Codex/tool launches from writing the same project cache and
# automation profile concurrently. This does not close or alter the user's
# interactive editor; -CloseRunningGodot remains the explicit exclusive mode.
$automationLockPath = Join-Path $projectRoot 'build\godot_tool.lock'
$automationLock = $null
try {
    $automationLock = [System.IO.File]::Open(
        $automationLockPath,
        [System.IO.FileMode]::OpenOrCreate,
        [System.IO.FileAccess]::ReadWrite,
        [System.IO.FileShare]::None
    )
} catch {
    throw (
        'Another Godot automation run already owns {0}. Wait for it to finish before launching another.' -f `
            $automationLockPath
    )
}

$writeProbePaths = @(
    (Join-Path $automationRoamingRoot ".write_probe_$PID"),
    (Join-Path $automationLocalRoot ".write_probe_$PID")
)
foreach ($writeProbePath in $writeProbePaths) {
    try {
        [System.IO.File]::WriteAllText(
            $writeProbePath,
            'godot-automation-profile'
        )
    } catch {
        throw (
            'Godot automation profile is not writable: {0}{1}{2}' -f `
                (Split-Path -Parent $writeProbePath),
                [Environment]::NewLine,
                $_.Exception.Message
        )
    } finally {
        if (Test-Path -LiteralPath $writeProbePath -PathType Leaf) {
            Remove-Item -LiteralPath $writeProbePath -Force
        }
    }
}

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

# --headless is added only when explicitly requested. The standard non-.NET
# build avoids the CoreCLR process seen in earlier Mono failures, while the
# normal Compatibility renderer remains the least disruptive project-script
# path tested here.
# Pack probes run from a separate directory so missing resources cannot fall
# back to the source checkout and make an incomplete export appear healthy.
$launchRoot = $projectRoot
if ($MainPack) {
    $launchRoot = Join-Path $projectRoot 'build\level_designer_export_run'
    New-Item -ItemType Directory -Path $launchRoot -Force | Out-Null
}
$arguments = @('--path', ('"{0}"' -f $launchRoot))
if ($MainPack) { $arguments += @('--main-pack', ('"{0}"' -f $resolvedPackPath)) }
if ($Headless) {
    $arguments += '--headless'
}
if ($ExportPack) {
    # --export-pack implies the dedicated import workflow and exits on completion.
    $arguments += @('--export-pack', $ExportPreset, ('"{0}"' -f $resolvedPackPath))
} elseif ($EditorImport) {
    # `--import` is Godot's dedicated editor import mode: it waits for pending
    # resources to finish before quitting. Do not replace it with
    # `--editor --quit`; `--quit` exits after the first iteration and previously
    # destroyed active import threads, producing a native access violation.
    $arguments += '--import'
} elseif ($Game) {
    if ($Visual) {
        $arguments += @('--resolution', ('{0}x{1}' -f $Width, $Height))
    }
} else {
    if ($Visual) {
        $arguments += @('--resolution', ('{0}x{1}' -f $Width, $Height))
    }
    $arguments += @('--script', $Script)
}

$logDirectory = Join-Path $projectRoot 'build\godot_tool_logs'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
$modeLabel = if ($ExportPack) {
    if ($Headless) { 'export_pack_headless' } else { 'export_pack' }
} elseif ($EditorImport) {
    'editor_import'
} elseif ($Game) {
    'game'
} elseif ($Visual) {
    'visual'
} elseif ($Headless) {
    'script_headless'
} else {
    'script'
}
$logPath = Join-Path $logDirectory (
    '{0}_{1:yyyyMMdd_HHmmss}_{2}.log' -f $modeLabel, (Get-Date), $PID
)
$arguments += @('--log-file', $logPath)

$previousAppData = $env:APPDATA
$previousLocalAppData = $env:LOCALAPPDATA
$exitCode = 1
try {
    $env:APPDATA = $automationRoamingRoot
    $env:LOCALAPPDATA = $automationLocalRoot
    # The Windows *_console.exe is a small launcher for the real executable.
    # Invoke the real process directly and wait for it so a delayed native
    # failure cannot be hidden behind a successful launcher exit code.
    $godotProcess = Start-Process `
        -FilePath $GodotExecutable `
        -ArgumentList $arguments `
        -WorkingDirectory $launchRoot `
        -PassThru `
        -Wait
    $exitCode = $godotProcess.ExitCode
    if ((-not $Game -or $exitCode -ne 0) -and (
            Test-Path -LiteralPath $logPath -PathType Leaf
        )) {
        Get-Content -LiteralPath $logPath
    }
    if ($exitCode -eq 0 -and ($Script -or $ExportPack)) {
        # A failed assert() aborts only the function it occurs in. The caller
        # keeps running and can still reach quit(0), so a tool script can
        # report success while an assertion inside a helper has failed. Treat
        # any script error in the log as a failed run.
        if (Test-Path -LiteralPath $logPath -PathType Leaf) {
            $scriptErrors = @(
                Select-String -LiteralPath $logPath -Pattern 'SCRIPT ERROR' -SimpleMatch
            )
            if ($scriptErrors.Count -gt 0) {
                $exitCode = 4
                [Console]::Error.WriteLine(
                    ("Godot $modeLabel reported {0} script error(s) despite " -f $scriptErrors.Count) +
                    "exiting cleanly. Log: $logPath"
                )
            }
        }
    }
    if ($exitCode -ne 0) {
        [Console]::Error.WriteLine(
            "Godot $modeLabel failed with exit code $exitCode. Log: $logPath"
        )
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalAppData
    if ($null -ne $automationLock) {
        $automationLock.Dispose()
    }
}
exit $exitCode
