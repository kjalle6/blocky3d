[CmdletBinding()]
param(
    [string]$AssetRoot = "D:\GodotProjects\blocky3dassets",
    [string]$OutputRoot = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = [System.IO.Path]::GetFullPath(
        (Join-Path $PSScriptRoot "..\assets\art\green_zone")
    )
}

$assets = [ordered]@{
    "characters/player_idle.png" =
        "weapons\beginner weapons\1 Characters\1 Biker\Idle.png"
    "characters/player_run.png" =
        "weapons\beginner weapons\1 Characters\1 Biker\Run.png"
    "characters/player_attack.png" =
        "weapons\beginner weapons\1 Characters\1 Biker\Attack.png"
    "characters/player_run_attack.png" =
        "weapons\beginner weapons\1 Characters\1 Biker\Run_attack.png"
    "characters/player_jump.png" =
        "characters\1 Biker\Biker_jump.png"
    "characters/player_hurt.png" =
        "characters\1 Biker\Biker_hurt.png"
    "characters/player_death.png" =
        "characters\1 Biker\Biker_death.png"
    "characters/weapon_idle.png" =
        "weapons\beginner weapons\2 Weapons\1 Idle\8.png"
    "characters/weapon_run.png" =
        "weapons\beginner weapons\2 Weapons\2 Run\8.png"
    "characters/weapon_attack.png" =
        "weapons\beginner weapons\2 Weapons\3 Attack\8.png"
    "characters/weapon_run_attack.png" =
        "weapons\beginner weapons\2 Weapons\4 Run_attack\8.png"
    "enemies/green_idle.png" =
        "enemies\green_zone_enemies\1\Idle.png"
    "enemies/green_walk.png" =
        "enemies\green_zone_enemies\1\Walk.png"
    "enemies/green_attack.png" =
        "enemies\green_zone_enemies\1\Attack.png"
    "enemies/green_death.png" =
        "enemies\green_zone_enemies\1\Death.png"
    "goal/chest_open.png" =
        "tilesets\green_zone\4 Animated objects\Chest_open.png"
    "props/tree.png" =
        "tilesets\green_zone\3 Objects\Other\Tree2.png"
    "props/bench.png" =
        "tilesets\green_zone\3 Objects\Benches\2.png"
    "props/bush.png" =
        "tilesets\green_zone\3 Objects\Bushes\3.png"
    "props/fence.png" =
        "tilesets\green_zone\3 Objects\Fence\3.png"
    "tiles/top_left.png" =
        "tilesets\green_zone\1 Tiles\Tile_01.png"
    "tiles/top.png" =
        "tilesets\green_zone\1 Tiles\Tile_02.png"
    "tiles/top_right.png" =
        "tilesets\green_zone\1 Tiles\Tile_03.png"
    "tiles/body_left.png" =
        "tilesets\green_zone\1 Tiles\Tile_13.png"
    "tiles/body.png" =
        "tilesets\green_zone\1 Tiles\Tile_14.png"
    "tiles/body_right.png" =
        "tilesets\green_zone\1 Tiles\Tile_15.png"
    "background/layer_1.png" =
        "tilesets\green_zone\2 Background\Day\1.png"
    "background/layer_2.png" =
        "tilesets\green_zone\2 Background\Day\2.png"
    "background/layer_3.png" =
        "tilesets\green_zone\2 Background\Day\3.png"
    "background/layer_4.png" =
        "tilesets\green_zone\2 Background\Day\4.png"
    "background/layer_5.png" =
        "tilesets\green_zone\2 Background\Day\5.png"
}

$licenses = [ordered]@{
    "licenses/characters_and_weapons.txt" =
        "weapons\beginner weapons\License.txt"
    "licenses/player_extra_animations.txt" =
        "characters\license.txt"
    "licenses/green_zone_enemies.txt" =
        "enemies\green_zone_enemies\License.txt"
    "licenses/green_zone_tileset.txt" =
        "tilesets\green_zone\license.txt"
}

$manifest = [ordered]@{}
foreach ($entry in $assets.GetEnumerator()) {
    $source = Join-Path $AssetRoot $entry.Value
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        throw "Missing green-zone source asset: $source"
    }

    $destination = Join-Path $OutputRoot $entry.Key
    $destinationDirectory = Split-Path -Parent $destination
    New-Item -ItemType Directory -Path $destinationDirectory -Force |
        Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force

    $manifest[$entry.Key] = [ordered]@{
        source = $entry.Value.Replace("\", "/")
        sha256 = (Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$treeSourcePath = Join-Path $OutputRoot "props/tree.png"
$treeGroundedPath = Join-Path $OutputRoot "props/tree_grounded.png"
Add-Type -AssemblyName System.Drawing
$treeSource = [System.Drawing.Bitmap]::FromFile($treeSourcePath)
try {
    $treeGrounded = New-Object System.Drawing.Bitmap (
        $treeSource.Width
    ), ($treeSource.Height - 1), (
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($treeGrounded)
        try {
            $graphics.CompositingMode =
                [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
            $graphics.DrawImageUnscaled($treeSource, 0, 0)
        }
        finally {
            $graphics.Dispose()
        }
        $treeGrounded.Save(
            $treeGroundedPath,
            [System.Drawing.Imaging.ImageFormat]::Png
        )
    }
    finally {
        $treeGrounded.Dispose()
    }
}
finally {
    $treeSource.Dispose()
}
$manifest["props/tree_grounded.png"] = [ordered]@{
    source = $assets["props/tree.png"].Replace("\", "/")
    transform = "Removed the final all-black pixel row for grounded rendering."
    sha256 = (Get-FileHash -LiteralPath $treeGroundedPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

foreach ($entry in $licenses.GetEnumerator()) {
    $source = Join-Path $AssetRoot $entry.Value
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) {
        Write-Warning "Optional license file was not found: $source"
        continue
    }
    $destination = Join-Path $OutputRoot $entry.Key
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force |
        Out-Null
    Copy-Item -LiteralPath $source -Destination $destination -Force
}

$manifestPath = Join-Path $OutputRoot "asset_manifest.json"
$manifest | ConvertTo-Json -Depth 4 |
    Set-Content -LiteralPath $manifestPath -Encoding utf8

Write-Output "Prepared $($assets.Count) green-zone assets in $OutputRoot"
