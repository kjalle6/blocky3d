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
    "characters/player_double_jump.png" =
        "characters\1 Biker\Biker_doublejump.png"
    "characters/player_dash.png" =
        "characters\animations\1\Dash.png"
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
    "props/tree_small.png" =
        "tilesets\green_zone\3 Objects\Other\Tree1.png"
    "props/bench.png" =
        "tilesets\green_zone\3 Objects\Benches\2.png"
    "props/bush.png" =
        "tilesets\green_zone\3 Objects\Bushes\3.png"
    "props/bush_low.png" =
        "tilesets\green_zone\3 Objects\Bushes\13.png"
    "props/bush_small.png" =
        "tilesets\green_zone\3 Objects\Bushes\16.png"
    "props/hedge_low_left.png" =
        "tilesets\green_zone\3 Objects\Bushes\9.png"
    "props/hedge_low_right.png" =
        "tilesets\green_zone\3 Objects\Bushes\12.png"
    "props/hedge_mid_left.png" =
        "tilesets\green_zone\3 Objects\Bushes\5.png"
    "props/hedge_mid_right.png" =
        "tilesets\green_zone\3 Objects\Bushes\8.png"
    "props/stone_small.png" =
        "tilesets\green_zone\3 Objects\Stones\2.png"
    "props/stone_medium.png" =
        "tilesets\green_zone\3 Objects\Stones\4.png"
    "props/fence.png" =
        "tilesets\green_zone\3 Objects\Fence\3.png"
    "props/garden_gate_open.png" =
        "tilesets\green_zone\3 Objects\Fence\2.png"
    "props/grass_tuft_sparse.png" =
        "tilesets\green_zone\3 Objects\Grass\5.png"
    "props/grass_tuft_thin.png" =
        "tilesets\green_zone\3 Objects\Grass\7.png"
    "props/grass_tuft_small.png" =
        "tilesets\green_zone\3 Objects\Grass\12.png"
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
        "tilesets\green_zone\1 Tiles\Tile_16.png"
    "tiles/deep_left.png" =
        "tilesets\green_zone\1 Tiles\Tile_61.png"
    "tiles/deep.png" =
        "tilesets\green_zone\1 Tiles\Tile_04.png"
    "tiles/deep_right.png" =
        "tilesets\green_zone\1 Tiles\Tile_62.png"
    "tiles/bottom_left.png" =
        "tilesets\green_zone\1 Tiles\Tile_25.png"
    "tiles/bottom.png" =
        "tilesets\green_zone\1 Tiles\Tile_26.png"
    "tiles/bottom_right.png" =
        "tilesets\green_zone\1 Tiles\Tile_28.png"
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
    "background/clouds/broad.png" =
        "environment\sky\clouds\PNG\Clouds_white\Shape2\cloud_shape2_3.png"
    "background/clouds/puff.png" =
        "environment\sky\clouds\PNG\Clouds_white\Shape3\cloud_shape3_4.png"
    "shoreline/tiles/top_left.png" =
        "tilesets\beach_zone\1 Tiles\SandTile_01.png"
    "shoreline/tiles/top.png" =
        "tilesets\beach_zone\1 Tiles\SandTile_02.png"
    "shoreline/tiles/top_right.png" =
        "tilesets\beach_zone\1 Tiles\SandTile_03.png"
    "shoreline/tiles/body_left.png" =
        "tilesets\beach_zone\1 Tiles\SandTile_08.png"
    "shoreline/tiles/body.png" =
        "tilesets\beach_zone\1 Tiles\SandTile_09.png"
    "shoreline/tiles/body_right.png" =
        "tilesets\beach_zone\1 Tiles\SandTile_10.png"
    "shoreline/water/surface_1.png" =
        "tilesets\beach_zone\1 Tiles\WaterTile_01.png"
    "shoreline/water/surface_2.png" =
        "tilesets\beach_zone\1 Tiles\WaterTile_02.png"
    "shoreline/water/surface_3.png" =
        "tilesets\beach_zone\1 Tiles\WaterTile_03.png"
    "shoreline/water/surface_4.png" =
        "tilesets\beach_zone\1 Tiles\WaterTile_04.png"
    "shoreline/water/body_1.png" =
        "tilesets\beach_zone\1 Tiles\WaterTile_05.png"
    "shoreline/water/body_2.png" =
        "tilesets\beach_zone\1 Tiles\WaterTile_06.png"
    "shoreline/water/body_3.png" =
        "tilesets\beach_zone\1 Tiles\WaterTile_07.png"
    "shoreline/water/body_4.png" =
        "tilesets\beach_zone\1 Tiles\WaterTile_08.png"
    "shoreline/water/water_tiles.png" =
        "tilesets\beach_zone\1 Tiles\WaterTiles.png"
    "shoreline/effects/water_death_splash.png" =
        "vfx\effects\1 Water splashes\48x\1.png"
    "shoreline/effects/wave_start.png" =
        "vfx\effects\3 Waves\1Start.png"
    "shoreline/effects/shore_foam.png" =
        "vfx\effects\1 Water splashes\48x\2.png"
    "shoreline/background/layer_1.png" =
        "tilesets\beach_zone\3 Background\Day\1.png"
    "shoreline/background/layer_2.png" =
        "tilesets\beach_zone\3 Background\Day\2.png"
    "shoreline/background/layer_3.png" =
        "tilesets\beach_zone\3 Background\Day\3.png"
    "shoreline/background/layer_4.png" =
        "tilesets\beach_zone\3 Background\Day\4.png"
    "shoreline/background/layer_5.png" =
        "tilesets\beach_zone\3 Background\Day\5.png"
    "shoreline/props/surfboard.png" =
        "tilesets\beach_zone\3 Objects\3 Other\1.png"
    "shoreline/props/umbrella.png" =
        "tilesets\beach_zone\3 Objects\3 Other\4.png"
    "shoreline/props/stone.png" =
        "tilesets\beach_zone\3 Objects\2 Stones\5.png"
    "shoreline/props/transition_stone_sand.png" =
        "tilesets\beach_zone\3 Objects\2 Stones\3.png"
    "shoreline/props/transition_pebble_sand.png" =
        "tilesets\beach_zone\3 Objects\2 Stones\4.png"
    "props/transition_pebble_green.png" =
        "tilesets\green_zone\3 Objects\Stones\1.png"
    "shoreline/props/transition_outcrop_tall.png" =
        "environment\rocks\PNG\middle_lane_rocks1\middle_lane_rock1_1.png"
    "shoreline/props/transition_outcrop_broad.png" =
        "environment\rocks\PNG\middle_lane_rocks1\middle_lane_rock1_2.png"
    "shoreline/props/transition_outcrop.png" =
        "environment\rocks\PNG\middle_lane_rocks1\middle_lane_rock1_3.png"
    "shoreline/props/transition_outcrop_medium.png" =
        "environment\rocks\PNG\middle_lane_rocks1\middle_lane_rock1_4.png"
    "shoreline/props/transition_outcrop_small.png" =
        "environment\rocks\PNG\middle_lane_rocks1\middle_lane_rock1_5.png"
}

$licenses = [ordered]@{
    "licenses/characters_and_weapons.txt" =
        "weapons\beginner weapons\License.txt"
    "licenses/player_extra_animations.txt" =
        "characters\license.txt"
    "licenses/player_dash_animation.txt" =
        "characters\animations\License.txt"
    "licenses/green_zone_enemies.txt" =
        "enemies\green_zone_enemies\License.txt"
    "licenses/green_zone_tileset.txt" =
        "tilesets\green_zone\license.txt"
    "licenses/beach_zone_tileset.txt" =
        "tilesets\beach_zone\license.txt"
    "licenses/water_effects.txt" =
        "vfx\effects\license.txt"
    "licenses/rocks.txt" =
        "environment\rocks\License.txt"
    "licenses/clouds.txt" =
        "environment\sky\clouds\License.txt"
    "licenses/tree_branch_pack.txt" =
        "environment\vegetation\trees\License.txt"
    "licenses/forest_background_pack.txt" =
        "backgrounds\forests_and_trees\license.txt"
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

Add-Type -AssemblyName System.Drawing

function New-SolidPixelSilhouette {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        [Parameter(Mandatory = $true)]
        [System.Drawing.Color]$Color
    )

    $source = [System.Drawing.Bitmap]::FromFile($SourcePath)
    try {
        $mapped = [System.Drawing.Bitmap]::new(
            $source.Width,
            $source.Height,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        try {
            for ($y = 0; $y -lt $source.Height; $y++) {
                for ($x = 0; $x -lt $source.Width; $x++) {
                    $sourceColor = $source.GetPixel($x, $y)
                    $mapped.SetPixel(
                        $x,
                        $y,
                        $(
                            if ($sourceColor.A -eq 0) {
                                [System.Drawing.Color]::Transparent
                            }
                            else {
                                [System.Drawing.Color]::FromArgb(
                                    $sourceColor.A,
                                    $Color.R,
                                    $Color.G,
                                    $Color.B
                                )
                            }
                        )
                    )
                }
            }
            New-Item -ItemType Directory -Path (
                Split-Path -Parent $DestinationPath
            ) -Force | Out-Null
            $mapped.Save(
                $DestinationPath,
                [System.Drawing.Imaging.ImageFormat]::Png
            )
        }
        finally { $mapped.Dispose() }
    }
    finally { $source.Dispose() }
}

function New-GroundedTree {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )
    $source = [System.Drawing.Bitmap]::FromFile($SourcePath)
    try {
        $grounded = [System.Drawing.Bitmap]::new(
            $source.Width,
            $source.Height - 1,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($grounded)
            try {
                $graphics.CompositingMode =
                    [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
                $graphics.DrawImageUnscaled($source, 0, 0)
            }
            finally { $graphics.Dispose() }
            $grounded.Save(
                $DestinationPath,
                [System.Drawing.Imaging.ImageFormat]::Png
            )
        }
        finally { $grounded.Dispose() }
    }
    finally { $source.Dispose() }
}

function Get-TransitionUnitNoise {
    param(
        [int]$X,
        [int]$Y,
        [int]$Salt
    )
    $value = (($X * 73) + ($Y * 151) + ($X * $Y * 19) + ($Salt * 199)) % 997
    if ($value -lt 0) { $value += 997 }
    return [double]$value / 996.0
}

function Get-ClampedUnit {
    param([double]$Value)
    return [Math]::Max(0.0, [Math]::Min(1.0, $Value))
}

function Get-PaletteBridgeColor {
    param(
        [System.Drawing.Color]$LeftColor,
        [System.Drawing.Color]$RightColor,
        [double]$Progress
    )
    $steppedProgress = [Math]::Round((Get-ClampedUnit $Progress) * 4.0) / 4.0
    $r = [int][Math]::Round(
        ($LeftColor.R * (1.0 - $steppedProgress) + $RightColor.R * $steppedProgress) / 8.0
    ) * 8
    $g = [int][Math]::Round(
        ($LeftColor.G * (1.0 - $steppedProgress) + $RightColor.G * $steppedProgress) / 8.0
    ) * 8
    $b = [int][Math]::Round(
        ($LeftColor.B * (1.0 - $steppedProgress) + $RightColor.B * $steppedProgress) / 8.0
    ) * 8
    return [System.Drawing.Color]::FromArgb(
        [Math]::Max($LeftColor.A, $RightColor.A),
        [Math]::Min(255, $r),
        [Math]::Min(255, $g),
        [Math]::Min(255, $b)
    )
}

function New-PixelTerrainTransitionTriplet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LeftPath,
        [Parameter(Mandatory = $true)]
        [string]$RightPath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationDirectory,
        [Parameter(Mandatory = $true)]
        [ValidateSet("StaggeredOrganic", "StaggeredPalette")]
        [string]$Mode,
        [Parameter(Mandatory = $true)]
        [string]$RowName
    )

    $left = [System.Drawing.Bitmap]::FromFile($LeftPath)
    $right = [System.Drawing.Bitmap]::FromFile($RightPath)
    try {
        if (
            $left.Width -ne 32 -or $left.Height -ne 32 -or
            $right.Width -ne 32 -or $right.Height -ne 32
        ) {
            throw "Terrain transition sources must both be 32 x 32 pixels."
        }

        $strip = [System.Drawing.Bitmap]::new(
            96,
            32,
            [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
        )
        try {
            for ($y = 0; $y -lt 32; $y++) {
                for ($x = 0; $x -lt 96; $x++) {
                    $localX = $x % 32
                    $leftColor = $left.GetPixel($localX, $y)
                    $rightColor = $right.GetPixel($localX, $y)
                    $cellX = [Math]::Floor($x / 3)
                    $cellY = [Math]::Floor($y / 3)
                    $noise = Get-TransitionUnitNoise $cellX $cellY 7
                    if ($Mode -eq "StaggeredOrganic") {
                        if ($x -lt 64) {
                            $color = $leftColor
                        }
                        else {
                            $progress = Get-ClampedUnit (($x - 64.0) / 31.0)
                            $wave = [Math]::Sin(($y + 2.0) * 0.68) * 0.09
                            $color = $(
                                if (($progress + $wave) -ge $noise) {
                                    $rightColor
                                }
                                else { $leftColor }
                            )
                        }
                    }
                    else {
                        # Let the approved surface takeover happen first.  The
                        # subterranean palette does not begin changing until the
                        # final tile, so the two boundaries no longer form one
                        # artificial vertical cut.
                        if ($x -lt 64) {
                            $color = $leftColor
                        }
                        else {
                            $waveOffset = [Math]::Sin(($y + 3.0) * 0.31) * 3.0
                            $progress = Get-ClampedUnit (
                                (($x - 64.0) + $waveOffset) / 31.0
                            )
                            $color = Get-PaletteBridgeColor `
                                $leftColor $rightColor $progress
                        }
                    }
                    $strip.SetPixel($x, $y, $color)
                }
            }
            New-Item -ItemType Directory -Path $DestinationDirectory -Force |
                Out-Null
            for ($column = 0; $column -lt 3; $column++) {
                $rectangle = [System.Drawing.Rectangle]::new(
                    $column * 32,
                    0,
                    32,
                    32
                )
                $tile = $strip.Clone(
                    $rectangle,
                    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
                )
                try {
                    $destination = Join-Path $DestinationDirectory (
                        "transition_{0}_{1}.png" -f $RowName, $column
                    )
                    $tile.Save(
                        $destination,
                        [System.Drawing.Imaging.ImageFormat]::Png
                    )
                }
                finally { $tile.Dispose() }
            }
        }
        finally {
            $strip.Dispose()
        }
    }
    finally {
        $left.Dispose()
        $right.Dispose()
    }
}

foreach ($tree in @(
    @{ source = "props/tree.png"; destination = "props/tree_grounded.png" },
    @{ source = "props/tree_small.png"; destination = "props/tree_small_grounded.png" }
)) {
    $treeSourcePath = Join-Path $OutputRoot $tree.source
    $treeGroundedPath = Join-Path $OutputRoot $tree.destination
    New-GroundedTree `
        -SourcePath $treeSourcePath `
        -DestinationPath $treeGroundedPath
    $manifest[$tree.destination] = [ordered]@{
        source = $assets[$tree.source].Replace("\", "/")
        transform = "Removed the final all-black pixel row for grounded rendering."
        sha256 = (Get-FileHash -LiteralPath $treeGroundedPath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$transitionDirectory = Join-Path $OutputRoot "shoreline/tiles"
New-PixelTerrainTransitionTriplet `
    -LeftPath (Join-Path $OutputRoot "shoreline/tiles/top.png") `
    -RightPath (Join-Path $OutputRoot "tiles/top.png") `
    -DestinationDirectory $transitionDirectory `
    -Mode StaggeredOrganic `
    -RowName top
New-PixelTerrainTransitionTriplet `
    -LeftPath (Join-Path $OutputRoot "shoreline/tiles/body.png") `
    -RightPath (Join-Path $OutputRoot "tiles/body.png") `
    -DestinationDirectory $transitionDirectory `
    -Mode StaggeredPalette `
    -RowName body
for ($column = 0; $column -lt 3; $column++) {
    foreach ($row in @("top", "body")) {
        $relativePath = "shoreline/tiles/transition_{0}_{1}.png" -f $row, $column
        $absolutePath = Join-Path $OutputRoot $relativePath
        $manifest[$relativePath] = [ordered]@{
            sources = @(
                $assets["shoreline/tiles/$row.png"].Replace("\", "/"),
                $assets["tiles/$row.png"].Replace("\", "/")
            )
            transform = $(
                if ($row -eq "top") {
                    "Rock-masked surface takeover held in the final tile, column $column."
                }
                else {
                    "One-tile-late, low-frequency palette bridge from sand body to Green Zone body, column $column."
                }
            )
            sha256 = (
                Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256
            ).Hash.ToLowerInvariant()
        }
    }
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

Write-Output "Prepared $($manifest.Count) green-zone assets in $OutputRoot"
