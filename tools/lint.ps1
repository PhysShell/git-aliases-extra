[CmdletBinding()]
param(
    [string]$Path = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    throw "PSScriptAnalyzer is not installed. Run: Install-Module PSScriptAnalyzer -Scope CurrentUser -Force"
}

Import-Module PSScriptAnalyzer -ErrorAction Stop

if (-not $Path) {
    $Path = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') |
        Select-Object -ExpandProperty Path -First 1
}

[string]$repoRoot = Resolve-Path -LiteralPath $Path | Select-Object -ExpandProperty Path -First 1
$settings = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
if (-not (Test-Path -LiteralPath $settings)) {
    throw "Missing PSScriptAnalyzerSettings.psd1 at: $repoRoot"
}

$targets = @(
    (Join-Path $repoRoot 'GitAliases.Extras.psm1'),
    (Join-Path $repoRoot 'GitAliases.Extras.psd1'),
    (Join-Path $repoRoot 'tests'),
    (Join-Path $repoRoot 'tools')
) | Where-Object { Test-Path -LiteralPath $_ }

$results = @()
foreach ($target in $targets) {
    $isDirectory = (Get-Item -LiteralPath $target).PSIsContainer
    if ($isDirectory) {
        $results += Invoke-ScriptAnalyzer -Path $target -Recurse -Settings $settings
    } else {
        $results += Invoke-ScriptAnalyzer -Path $target -Settings $settings
    }
}

if ($results -and $results.Count -gt 0) {
    $results |
        Sort-Object ScriptName, Line, RuleName |
        Format-Table Severity, RuleName, ScriptName, Line, Column, Message -AutoSize |
        Out-String |
        Write-Host

    throw "PSScriptAnalyzer found issues: $($results.Count)"
}

Write-Host 'PSScriptAnalyzer: no issues found.'
