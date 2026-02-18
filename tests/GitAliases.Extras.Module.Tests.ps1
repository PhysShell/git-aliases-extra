$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

BeforeAll {
    [string]$script:RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') |
        Select-Object -ExpandProperty Path -First 1
    $script:ModuleManifest = Join-Path $script:RepoRoot 'GitAliases.Extras.psd1'

    if (Get-Module -ListAvailable -Name git-aliases) {
        Import-Module git-aliases -DisableNameChecking -ErrorAction SilentlyContinue
    }

    Import-Module $script:ModuleManifest -Force
}

AfterAll {
    Remove-Module GitAliases.Extras -Force -ErrorAction SilentlyContinue
}

Describe 'GitAliases.Extras manifest' {
    It 'is a valid module manifest' {
        $manifest = Test-ModuleManifest -Path $script:ModuleManifest -ErrorAction Stop
        $manifest.Name | Should -Be 'GitAliases.Extras'
    }

    It 'declares gallery metadata and required modules' {
        $manifest = Import-PowerShellDataFile -Path $script:ModuleManifest
        $manifest.PrivateData.PSData.ProjectUri | Should -Match '^https://github.com/PhysShell/GitAliases\.Extras'
        $manifest.PrivateData.PSData.LicenseUri | Should -Match '/LICENSE$'

        $requiredModuleNames = @($manifest.RequiredModules | ForEach-Object {
            if ($_ -is [string]) { $_ } else { $_.ModuleName }
        })
        $requiredModuleNames | Should -Contain 'posh-git'
        $requiredModuleNames | Should -Contain 'git-aliases'
    }
}

Describe 'GitAliases.Extras module exports' {
    It 'imports successfully' {
        Get-Module GitAliases.Extras | Should -Not -BeNullOrEmpty
    }

    It 'exports key commands' {
        Get-Command gsw -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command gfp -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command Register-GitAliasCompletion -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }
}
