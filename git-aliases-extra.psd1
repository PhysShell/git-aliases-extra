@{
    RootModule = 'git-aliases-extra.psm1'
    ModuleVersion = '0.1.3'
    GUID = 'a5c2859e-7dce-4853-9db5-8cb7927dbdda'
    Author = 'PhysShell'
    CompanyName = ''
    Copyright = 'Copyright (c) PhysShell 2026.'
    Description = 'Custom git aliases and robust tab completion helpers for PowerShell.'
    PowerShellVersion = '5.1'
    HelpInfoURI = 'https://github.com/PhysShell/git-aliases-extra'
    CompatiblePSEditions = @('Desktop', 'Core')
    FunctionsToExport = @(
        'Test-InGitRepo',
        'Test-GitInProgress',
        'Test-WorkingTreeClean',
        'Get-CurrentBranch',
        'Test-GitRefExists',
        'Get-Git-Aliases',
        'UpMerge',
        'UpRebase',
        'gapt',
        'gcor',
        'gdct',
        'gdt',
        'gdnolock',
        'gdv',
        'gfo',
        'gwt',
        'gwta',
        'gwtl',
        'gwtm',
        'gwtr',
        'gwtp',
        'glp',
        'gmtl',
        'gmtlvim',
        'gtv',
        'gtl',
        'gwip',
        'gunwip',
        'grsh',
        'gccd',
        'grl',
        'ghash',
        'gfp',
        'gsw',
        'gswc',
        'Register-GitAliasCompletion'
    )
    AliasesToExport = @('gum', 'gur', 'gh')
    CmdletsToExport = @()
    VariablesToExport = '*'
    RequiredModules = @(
        @{
            ModuleName = 'posh-git'
            ModuleVersion = '1.1.0'
        },
        @{
            ModuleName = 'git-aliases'
            ModuleVersion = '0.3.8'
        }
    )
    PrivateData = @{
        PSData = @{
            Tags = @('git', 'aliases', 'completion', 'posh-git', 'powershell', 'worktree')
            ProjectUri = 'https://github.com/PhysShell/git-aliases-extra'
            LicenseUri = 'https://github.com/PhysShell/git-aliases-extra/blob/main/LICENSE'
            IconUri = 'https://raw.githubusercontent.com/PhysShell/git-aliases-extra/main/assets/icon.png'
            RepositorySourceLocation = 'https://github.com/PhysShell/git-aliases-extra'
            ReleaseNotes = 'See CHANGELOG.md for release notes.'
            RequireLicenseAcceptance = $false
        }
    }
}
