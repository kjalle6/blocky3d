param(
    [string]$InputDirectory = "",

    [string]$Filter = "*.png",

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [int]$Columns = 3,
    [int]$CellWidth = 640,
    [int]$LabelHeight = 28,

    [Parameter(Position = 0)]
    [string[]]$InputPaths = @()
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

if ($Columns -lt 1 -or $CellWidth -lt 64 -or $LabelHeight -lt 0) {
    throw "Columns, CellWidth, and LabelHeight must describe a usable sheet."
}

$files = @()
if (-not [string]::IsNullOrWhiteSpace($InputDirectory)) {
    $files = @(
        Get-ChildItem -LiteralPath $InputDirectory -File -Filter $Filter |
            Sort-Object Name
    )
}
else {
    $files = @(
        foreach ($path in $InputPaths) {
            $resolved = Resolve-Path -LiteralPath $path -ErrorAction Stop
            Get-Item -LiteralPath $resolved.Path
        }
    )
}
if ($files.Count -eq 0) {
    throw "At least one review image is required."
}

$images = @()
try {
    foreach ($file in $files) {
        $images += [System.Drawing.Bitmap]::FromFile($file.FullName)
    }

    $aspectRatio = $images[0].Height / [double]$images[0].Width
    $imageHeight = [int][Math]::Round($CellWidth * $aspectRatio)
    $cellHeight = $imageHeight + $LabelHeight
    $rows = [int][Math]::Ceiling($files.Count / [double]$Columns)
    $sheet = [System.Drawing.Bitmap]::new($CellWidth * $Columns, $cellHeight * $rows)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($sheet)
        try {
            $graphics.Clear([System.Drawing.Color]::FromArgb(255, 25, 30, 42))
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
            $font = [System.Drawing.Font]::new("Consolas", 12)
            $labelBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
            $borderPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 95, 110, 140))
            try {
                for ($index = 0; $index -lt $files.Count; $index++) {
                    $column = $index % $Columns
                    $row = [int][Math]::Floor($index / [double]$Columns)
                    $x = $column * $CellWidth
                    $y = $row * $cellHeight
                    $graphics.DrawImage(
                        $images[$index],
                        [System.Drawing.Rectangle]::new($x, $y, $CellWidth, $imageHeight),
                        0,
                        0,
                        $images[$index].Width,
                        $images[$index].Height,
                        [System.Drawing.GraphicsUnit]::Pixel
                    )
                    $graphics.DrawRectangle($borderPen, $x, $y, $CellWidth - 1, $cellHeight - 1)
                    $graphics.DrawString(
                        $files[$index].BaseName,
                        $font,
                        $labelBrush,
                        $x + 5,
                        $y + $imageHeight + 4
                    )
                }
            }
            finally {
                $font.Dispose()
                $labelBrush.Dispose()
                $borderPen.Dispose()
            }
        }
        finally { $graphics.Dispose() }

        $outputDirectory = Split-Path -Parent $OutputPath
        if ($outputDirectory) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }
        $sheet.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output $OutputPath
    }
    finally { $sheet.Dispose() }
}
finally {
    foreach ($image in $images) {
        $image.Dispose()
    }
}
