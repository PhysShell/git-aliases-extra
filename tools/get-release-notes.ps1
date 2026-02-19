[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$ChangelogPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not $ChangelogPath) {
    $ChangelogPath = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\CHANGELOG.md') |
        Select-Object -ExpandProperty Path -First 1
}

if (-not (Test-Path -LiteralPath $ChangelogPath)) {
    throw "Changelog not found: $ChangelogPath"
}

[string[]]$lines = Get-Content -LiteralPath $ChangelogPath
[string]$escapedVersion = [Regex]::Escape($Version)
[string]$versionHeaderPattern = "^##\s+\[$escapedVersion\]\s+-\s+\d{4}-\d{2}-\d{2}\s*$"

[int]$startIndex = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match $versionHeaderPattern) {
        $startIndex = $i
        break
    }
}

if ($startIndex -lt 0) {
    throw "No changelog section found for version '$Version' in '$ChangelogPath'."
}

[int]$endIndex = $lines.Count
for ($i = $startIndex + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^##\s+\[') {
        $endIndex = $i
        break
    }
}

if ($endIndex -le ($startIndex + 1)) {
    throw "Changelog section for version '$Version' is empty."
}

[string]$notes = ($lines[($startIndex + 1)..($endIndex - 1)] -join [Environment]::NewLine).Trim()
if (-not $notes) {
    throw "Changelog section for version '$Version' is empty."
}

$notes
