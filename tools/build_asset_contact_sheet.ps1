param(
    [Parameter(Mandatory = $true)]
    [string]$InputDirectory,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [int]$Columns = 12,
    [int]$Scale = 4
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$files = Get-ChildItem -LiteralPath $InputDirectory -File -Filter "*.png" |
    Sort-Object { if ($_.BaseName -match "(\d+)$") { [int]$Matches[1] } else { [int]::MaxValue } }, Name

if ($files.Count -eq 0) {
    throw "No PNG files found in $InputDirectory"
}

$sourceImages = @()
try {
    foreach ($file in $files) {
        $sourceImages += [System.Drawing.Bitmap]::FromFile($file.FullName)
    }

    $maxWidth = ($sourceImages | Measure-Object -Property Width -Maximum).Maximum
    $maxHeight = ($sourceImages | Measure-Object -Property Height -Maximum).Maximum
    $labelHeight = 22
    $cellWidth = $maxWidth * $Scale
    $cellHeight = ($maxHeight * $Scale) + $labelHeight
    $rows = [Math]::Ceiling($files.Count / [double]$Columns)

    $sheetWidth = [int]($cellWidth * $Columns)
    $sheetHeight = [int]($cellHeight * $rows)
    $sheet = [System.Drawing.Bitmap]::new($sheetWidth, $sheetHeight)
    $graphics = [System.Drawing.Graphics]::FromImage($sheet)
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(255, 40, 45, 58))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $font = New-Object System.Drawing.Font "Consolas", 10
        $labelBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::White)
        $gridPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 90, 98, 116))
        try {
            for ($index = 0; $index -lt $files.Count; $index++) {
                $column = $index % $Columns
                $row = [Math]::Floor($index / $Columns)
                $x = $column * $cellWidth
                $y = $row * $cellHeight
                $image = $sourceImages[$index]
                $drawX = $x + [Math]::Floor(($cellWidth - ($image.Width * $Scale)) / 2)
                $graphics.DrawImage(
                    $image,
                    [System.Drawing.Rectangle]::new($drawX, $y, $image.Width * $Scale, $image.Height * $Scale),
                    0,
                    0,
                    $image.Width,
                    $image.Height,
                    [System.Drawing.GraphicsUnit]::Pixel
                )
                $graphics.DrawRectangle($gridPen, $x, $y, $cellWidth - 1, $cellHeight - 1)
                $graphics.DrawString($files[$index].BaseName, $font, $labelBrush, $x + 4, $y + ($maxHeight * $Scale) + 2)
            }
        }
        finally {
            $font.Dispose()
            $labelBrush.Dispose()
            $gridPen.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
    }

    $outputDirectory = Split-Path -Parent $OutputPath
    if ($outputDirectory) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    $sheet.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $sheet.Dispose()
    Write-Output $OutputPath
}
finally {
    foreach ($image in $sourceImages) {
        $image.Dispose()
    }
}
