$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

BeforeAll {
    [string]$script:RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') |
        Select-Object -ExpandProperty Path -First 1
    $script:ModuleManifest = Join-Path $script:RepoRoot 'git-aliases-extra.psd1'

    if (Get-Module -ListAvailable -Name git-aliases) {
        Import-Module git-aliases -DisableNameChecking -ErrorAction SilentlyContinue
    }

    Import-Module $script:ModuleManifest -Force
}

AfterAll {
    Remove-Module git-aliases-extra -Force -ErrorAction SilentlyContinue
}

Describe 'git-aliases-extra manifest' {
    It 'is a valid module manifest' {
        $manifest = Test-ModuleManifest -Path $script:ModuleManifest -ErrorAction Stop
        $manifest.Name | Should -Be 'git-aliases-extra'
    }

    It 'declares gallery metadata and required modules' {
        $manifest = Import-PowerShellDataFile -Path $script:ModuleManifest
        $manifest.PrivateData.PSData.ProjectUri | Should -Match '^https://github.com/PhysShell/git-aliases-extra'
        $manifest.PrivateData.PSData.LicenseUri | Should -Match '/LICENSE$'

        $requiredModuleNames = @($manifest.RequiredModules | ForEach-Object {
            if ($_ -is [string]) { $_ } else { $_.ModuleName }
        })
        $requiredModuleNames | Should -Contain 'posh-git'
        $requiredModuleNames | Should -Contain 'git-aliases'
    }
}

Describe 'git-aliases-extra module exports' {
    It 'imports successfully' {
        Get-Module git-aliases-extra | Should -Not -BeNullOrEmpty
    }

    It 'exports key commands' {
        Get-Command gsw -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command gfp -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command gwt -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command gwtr -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command Register-GitAliasCompletion -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }
}

Describe 'git-aliases-extra tooling' {
    It 'includes install-hooks and hook templates' {
        (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'tools\install-hooks.ps1')) | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'tools\hooks\pre-commit')) | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'tools\hooks\commit-msg')) | Should -BeTrue
    }
}
