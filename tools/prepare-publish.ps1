[CmdletBinding()]
param(
    [string]$SourcePath = '',
    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $SourcePath) {
    $SourcePath = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') |
        Select-Object -ExpandProperty Path -First 1
} else {
    $SourcePath = Resolve-Path -LiteralPath $SourcePath |
        Select-Object -ExpandProperty Path -First 1
}

if (-not $OutputPath) {
    $OutputPath = Join-Path ([IO.Path]::GetTempPath()) ("git-aliases-extra-publish-{0}" -f [guid]::NewGuid().ToString('N'))
}

$manifestPath = Join-Path $SourcePath 'git-aliases-extra.psd1'
if (-not (Test-Path -LiteralPath $manifestPath)) {
    throw "Manifest not found: $manifestPath"
}

$manifest = Test-ModuleManifest -Path $manifestPath -ErrorAction Stop

if (Test-Path -LiteralPath $OutputPath) {
    Remove-Item -LiteralPath $OutputPath -Recurse -Force
}

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

$filesToCopy = @(
    'git-aliases-extra.psd1',
    $manifest.RootModule,
    'README.md',
    'LICENSE',
    'CHANGELOG.md'
) | Select-Object -Unique

foreach ($relativePath in $filesToCopy) {
    $source = Join-Path $SourcePath $relativePath
    if (-not (Test-Path -LiteralPath $source)) {
        throw "Required publish file missing: $relativePath"
    }

    $destination = Join-Path $OutputPath $relativePath
    $destinationDir = Split-Path -Parent $destination
    if ($destinationDir -and -not (Test-Path -LiteralPath $destinationDir)) {
        New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }

    Copy-Item -LiteralPath $source -Destination $destination -Force
}

$optionalDirs = @('assets')
foreach ($dirName in $optionalDirs) {
    $sourceDir = Join-Path $SourcePath $dirName
    if (-not (Test-Path -LiteralPath $sourceDir)) {
        continue
    }

    Copy-Item -LiteralPath $sourceDir -Destination (Join-Path $OutputPath $dirName) -Recurse -Force
}

Test-ModuleManifest -Path (Join-Path $OutputPath 'git-aliases-extra.psd1') -ErrorAction Stop | Out-Null

$OutputPath
