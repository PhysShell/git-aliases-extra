[CmdletBinding()]
param(
    [string]$TestsPath = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Get-Module -ListAvailable -Name Pester)) {
    throw "Pester is not installed. Run: Install-Module Pester -Scope CurrentUser -Force"
}

Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop

if (-not $TestsPath) {
    $TestsPath = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\tests') |
        Select-Object -ExpandProperty Path -First 1
}

if (-not (Test-Path -LiteralPath $TestsPath)) {
    throw "Tests folder not found: $TestsPath"
}

$result = Invoke-Pester -Path $TestsPath -CI -PassThru
if ($result.FailedCount -gt 0) {
    throw "Pester failed: $($result.FailedCount) test(s) failed."
}

Write-Host "Pester: all tests passed ($($result.PassedCount) passed)."
