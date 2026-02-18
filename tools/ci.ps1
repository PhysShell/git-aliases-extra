[CmdletBinding()]
param(
    [switch]$LintOnly,
    [switch]$TestOnly
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

[string]$root = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') |
    Select-Object -ExpandProperty Path -First 1

if (-not $TestOnly) {
    & (Join-Path $root 'tools\lint.ps1')
}

if (-not $LintOnly) {
    & (Join-Path $root 'tools\test.ps1')
}

Write-Host 'CI checks completed.'
