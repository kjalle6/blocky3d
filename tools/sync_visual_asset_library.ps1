[CmdletBinding()]
param(
    [string]$AssetRoot = 'D:\GodotProjects\blocky3dassets',
    [string]$OutputRoot = ''
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
    $OutputRoot = Join-Path $projectRoot 'assets\library'
}

if (-not (Test-Path -LiteralPath $AssetRoot -PathType Container)) {
    throw "Asset library was not found: $AssetRoot"
}

$assetRootPath = (Resolve-Path -LiteralPath $AssetRoot).Path
$outputRootPath = [System.IO.Path]::GetFullPath($OutputRoot)
$projectPrefix = $projectRoot.TrimEnd('\', '/') + `
    [System.IO.Path]::DirectorySeparatorChar
$assetRootPrefix = $assetRootPath.TrimEnd('\', '/') + `
    [System.IO.Path]::DirectorySeparatorChar
if (-not $outputRootPath.StartsWith(
        $projectPrefix,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "Refusing to synchronize assets outside the project: $outputRootPath"
}

$allowedExtensions = @('.png', '.svg', '.ttf', '.otf', '.txt')
$excludedTopLevel = @('_inbox', 'audio')
$excludedDirectoryNames = @('__MACOSX')
$excludedFileNames = @('.DS_Store', 'Thumbs.db')
$pathSeparators = [char[]]@(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)

$sourceFiles = @(
    Get-ChildItem -LiteralPath $assetRootPath -Recurse -File -Force |
        ForEach-Object {
            if (-not $_.FullName.StartsWith(
                    $assetRootPrefix,
                    [System.StringComparison]::OrdinalIgnoreCase
                )) {
                throw "Asset escaped the source library: $($_.FullName)"
            }
            $relativePath = $_.FullName.Substring($assetRootPrefix.Length)
            $segments = $relativePath.Split(
                $pathSeparators,
                [System.StringSplitOptions]::RemoveEmptyEntries
            )
            if ($segments.Count -eq 0) {
                return
            }
            if ($excludedTopLevel -contains $segments[0]) {
                return
            }
            foreach ($segment in $segments) {
                if ($excludedDirectoryNames -contains $segment) {
                    return
                }
            }
            if ($excludedFileNames -contains $_.Name) {
                return
            }
            if ($allowedExtensions -notcontains $_.Extension.ToLowerInvariant()) {
                return
            }
            [pscustomobject]@{
                Source = $_
                RelativePath = $relativePath
            }
        } |
        Sort-Object RelativePath
)

if ($sourceFiles.Count -eq 0) {
    throw "No supported visual assets were found below $assetRootPath"
}

New-Item -ItemType Directory -Path $outputRootPath -Force | Out-Null
$copied = 0
$updated = 0
$unchanged = 0
$retained = 0
$manifestFiles = [System.Collections.Generic.List[object]]::new()
$sourcePaths = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($entry in $sourceFiles) {
    [void]$sourcePaths.Add($entry.RelativePath)
    $sourceFile = $entry.Source
    $destinationPath = Join-Path $outputRootPath $entry.RelativePath
    $sourceHash = (
        Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $needsCopy = $true
    $wasPresent = Test-Path -LiteralPath $destinationPath -PathType Leaf
    if ($wasPresent) {
        $destinationFile = Get-Item -LiteralPath $destinationPath
        if ($destinationFile.Length -eq $sourceFile.Length) {
            $destinationHash = (
                Get-FileHash -LiteralPath $destinationPath -Algorithm SHA256
            ).Hash.ToLowerInvariant()
            $needsCopy = $destinationHash -ne $sourceHash
        }
    }

    if ($needsCopy) {
        New-Item -ItemType Directory -Path (
            Split-Path -Parent $destinationPath
        ) -Force | Out-Null
        Copy-Item -LiteralPath $sourceFile.FullName -Destination $destinationPath -Force
        if ($wasPresent) {
            $updated += 1
        } else {
            $copied += 1
        }
    } else {
        $unchanged += 1
    }

    $manifestFiles.Add([ordered]@{
        path = $entry.RelativePath.Replace('\', '/')
        bytes = $sourceFile.Length
        sha256 = $sourceHash
    })
}

# Renamed source folders and project-authored catalog art can leave useful
# files only in the mirror. Preserve their paths and keep them discoverable
# in the manifest instead of silently dropping their records on every sync.
$outputRootPrefix = $outputRootPath.TrimEnd('\', '/') + `
    [System.IO.Path]::DirectorySeparatorChar
foreach ($file in Get-ChildItem -LiteralPath $outputRootPath -Recurse -File -Force) {
    if ($allowedExtensions -notcontains $file.Extension.ToLowerInvariant()) {
        continue
    }
    $relativePath = $file.FullName.Substring($outputRootPrefix.Length)
    $segments = $relativePath.Split($pathSeparators)
    if ($excludedTopLevel -contains $segments[0] -or
        $segments -contains '__MACOSX' -or
        $excludedFileNames -contains $file.Name -or
        $sourcePaths.Contains($relativePath)) {
        continue
    }
    $manifestFiles.Add([ordered]@{
        path = $relativePath.Replace('\', '/')
        bytes = $file.Length
        sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        source_status = 'library_only'
    })
    $retained += 1
}

$manifest = [ordered]@{
    schema_version = 1
    source_library = 'blocky3dassets'
    included_extensions = $allowedExtensions
    excluded_top_level = $excludedTopLevel
    file_count = $manifestFiles.Count
    files = @($manifestFiles | Sort-Object { $_.path.Replace('/', '\') })
}
$manifestPath = Join-Path $outputRootPath 'library_manifest.json'
$manifestJson = $manifest | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText(
    $manifestPath,
    $manifestJson + [Environment]::NewLine,
    [System.Text.UTF8Encoding]::new($false)
)

Write-Host (
    'Visual library synchronized: {0} files ({1} copied, {2} updated, {3} unchanged, {4} retained only in library).' -f `
        $manifestFiles.Count,
        $copied,
        $updated,
        $unchanged,
        $retained
)
Write-Host "Destination: $outputRootPath"
