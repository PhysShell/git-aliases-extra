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
        $manifest.PrivateData.PSData.IconUri | Should -Match '/assets/icon\.png$'
        $manifest.PrivateData.PSData.ReleaseNotes | Should -Not -BeNullOrEmpty
        $manifest.Copyright | Should -Match '\b\d{4}\b'

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

    It 'includes changelog, icon and release notes helper script' {
        (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'CHANGELOG.md')) | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'assets\icon.png')) | Should -BeTrue
        (Test-Path -LiteralPath (Join-Path $script:RepoRoot 'tools\get-release-notes.ps1')) | Should -BeTrue
    }

    It 'resolves release notes from changelog for manifest version' {
        $manifest = Test-ModuleManifest -Path $script:ModuleManifest -ErrorAction Stop
        $version = $manifest.Version.ToString()
        $scriptPath = Join-Path $script:RepoRoot 'tools\get-release-notes.ps1'
        $notes = & $scriptPath -Version $version
        $notes | Should -Not -BeNullOrEmpty
    }
}
