[CmdletBinding()]
param(
    [string]$AssetRoot = 'D:\GodotProjects\blocky3dassets',
    [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $PSScriptRoot '..\assets\art\green_zone'
}

$roll = [System.Drawing.Bitmap]::new((Join-Path $AssetRoot 'characters\1 Biker\Biker_doublejump.png'))
$jump = [System.Drawing.Bitmap]::new((Join-Path $AssetRoot 'weapons\guns_pack_1\1 Characters\1 Biker\Jump1.png'))
if ($roll.Width -ne 288 -or $roll.Height -ne 48 -or $jump.Width -ne 192 -or $jump.Height -ne 48) {
    $jump.Dispose()
    $roll.Dispose()
    throw 'The handgun flip recipe requires six 48px double-jump frames and four 48px Jump1 frames.'
}
$output = $roll.Clone(
    [System.Drawing.Rectangle]::new(0, 0, 288, 48),
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)
try {
    # Remove only the outer silhouette of the tucked firing arm. Each row
    # records frame, Y, first X, last X in the original 48px source frame.
    # The far arm, torso, face, legs, palette, and flip timing are retained.
    $armRows = @(
        @(0,27,22,23), @(0,28,17,22), @(0,29,17,21), @(0,30,16,20),
        @(0,31,16,19), @(0,32,15,19), @(0,33,15,18),
        @(1,26,16,17), @(1,27,14,17), @(1,28,13,18), @(1,29,12,18),
        @(1,30,12,19), @(1,31,13,16),
        @(2,17,24,26), @(2,18,23,27), @(2,19,23,27), @(2,20,22,27),
        @(2,21,22,27), @(2,22,22,26), @(2,23,22,26), @(2,24,22,25),
        @(2,25,22,25),
        @(3,14,15,18), @(3,15,14,19), @(3,16,14,20), @(3,17,15,20),
        @(3,18,15,20), @(3,19,16,20), @(3,20,16,20), @(3,21,17,19)
    )
    foreach ($row in $armRows) {
        for ($x = $row[2]; $x -le $row[3]; $x++) {
            $output.SetPixel($row[0] * 48 + $x, $row[1], [System.Drawing.Color]::Transparent)
        }
    }
    # The last two poses match Jump1 frames 2/3 exactly except for the
    # removed arm. Reuse those authored poses rather than trim them again.
    for ($frame = 4; $frame -lt 6; $frame++) {
        for ($y = 0; $y -lt 48; $y++) {
            for ($x = 0; $x -lt 48; $x++) {
                $output.SetPixel($frame * 48 + $x, $y, $jump.GetPixel(($frame - 2) * 48 + $x, $y))
            }
        }
    }
    $destination = Join-Path $OutputRoot 'characters\player_handgun_double_jump.png'
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    $output.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $output.Dispose()
    $jump.Dispose()
    $roll.Dispose()
}
