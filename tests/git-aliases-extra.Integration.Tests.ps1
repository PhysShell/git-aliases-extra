$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:HasGcoAlias = [bool](Get-Command gco -ErrorAction SilentlyContinue)

BeforeAll {
    function Script:Invoke-GitCommand {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$RepoPath,
            [Parameter(Mandatory = $true)]
            [string[]]$Arguments,
            [switch]$AllowFail
        )

        $previousPreference = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $output = & git -C $RepoPath @Arguments 2>&1
        } finally {
            $ErrorActionPreference = $previousPreference
        }
        $exitCode = $LASTEXITCODE
        $text = ($output | Out-String).Trim()

        if (-not $AllowFail -and $exitCode -ne 0) {
            throw "git $($Arguments -join ' ') failed in '$RepoPath' (exit=$exitCode): $text"
        }

        [pscustomobject]@{
            ExitCode = $exitCode
            Output = $text
        }
    }

    function Script:Find-BlobPrefixCollision {
        [CmdletBinding()]
        param(
            [string]$Prefix = '8695',
            [int]$MaxAttempts = 2000000
        )

        $sha1 = [System.Security.Cryptography.SHA1]::Create()
        try {
            for ($i = 0; $i -lt $MaxAttempts; $i++) {
                $content = "collision-$i"
                $contentBytes = [Text.Encoding]::ASCII.GetBytes($content)
                $headerBytes = [Text.Encoding]::ASCII.GetBytes("blob $($contentBytes.Length)`0")

                $payload = New-Object byte[] ($headerBytes.Length + $contentBytes.Length)
                [Buffer]::BlockCopy($headerBytes, 0, $payload, 0, $headerBytes.Length)
                [Buffer]::BlockCopy($contentBytes, 0, $payload, $headerBytes.Length, $contentBytes.Length)

                $hashBytes = $sha1.ComputeHash($payload)
                $hash = ([BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
                if ($hash.StartsWith($Prefix)) {
                    return [pscustomobject]@{
                        Content = $content
                        Hash = $hash
                    }
                }
            }
        } finally {
            $sha1.Dispose()
        }

        throw "Could not find blob hash prefix '$Prefix' within $MaxAttempts attempts."
    }

    function Script:Get-TabCompletionResult {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$Line
        )

        TabExpansion2 -inputScript $Line -cursorColumn $Line.Length
    }

    function Script:Get-LongOptionCompletionResult {
        [CmdletBinding()]
        param(
            [Parameter(Mandatory = $true)]
            [string]$CommandName,
            [Parameter(Mandatory = $true)]
            [string]$FallbackPrefix
        )

        # In Windows PowerShell 5.1, a bare "--" token is parsed in a way that
        # often bypasses argument completers entirely. Probe with "--" first,
        # then retry with a concrete prefix to validate long-option completion.
        $result = Get-TabCompletionResult -Line ("{0} --" -f $CommandName)
        if ($result.CompletionMatches.Count -gt 0 -or $PSVersionTable.PSVersion.Major -ge 6) {
            return $result
        }

        return (Get-TabCompletionResult -Line ("{0} {1}" -f $CommandName, $FallbackPrefix))
    }

    [string]$script:RepoRoot = Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..') |
        Select-Object -ExpandProperty Path -First 1
    $script:ModuleManifest = Join-Path $script:RepoRoot 'git-aliases-extra.psd1'

    if (Get-Module -ListAvailable -Name git-aliases) {
        Import-Module git-aliases -DisableNameChecking -ErrorAction SilentlyContinue
    }

    Import-Module $script:ModuleManifest -Force
    $script:HasGcoAlias = [bool](Get-Command gco -ErrorAction SilentlyContinue)
}

AfterAll {
    Remove-Module git-aliases-extra -Force -ErrorAction SilentlyContinue
}

Describe 'git-aliases-extra module' {
    It 'imports successfully' {
        Get-Module git-aliases-extra | Should -Not -BeNullOrEmpty
    }

    It 'exports expected commands' {
        Get-Command Test-InGitRepo -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command UpMerge -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command UpRebase -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command Get-Git-Aliases -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command gfp -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command gsw -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command gwt -ErrorAction Stop | Should -Not -BeNullOrEmpty
        Get-Command gwtr -ErrorAction Stop | Should -Not -BeNullOrEmpty
    }

    It 'Test-InGitRepo returns a boolean value outside or inside a repository' {
        (Test-InGitRepo).GetType().Name | Should -Be 'Boolean'
    }

    It 'Get-Git-Aliases resolves custom alias grsh' {
        $definition = Get-Git-Aliases grsh
        $definition | Should -Match 'git reset --soft HEAD~1'
    }

    It 'Get-Git-Aliases lists aliases from git-aliases-extra' {
        $allAliasesText = (Get-Git-Aliases | Out-String)
        $allAliasesText | Should -Match '(?im)^\s*grsh\s+'
        $allAliasesText | Should -Match '(?im)^\s*gfp\s+'
    }

    It 'Get-Git-Aliases returns extras first and keeps alphabetical order per group' {
        $allAliasesText = (Get-Git-Aliases | Out-String)
        $lines = $allAliasesText -split "`r?`n"

        $extrasNames = @()
        $baseNames = @()
        $firstBaseLine = -1
        $lastExtrasLine = -1

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '^\s*([^\s]+)\s+extras\s+') {
                $extrasNames += $matches[1]
                $lastExtrasLine = $i
                continue
            }

            if ($line -match '^\s*([^\s]+)\s+base\s+') {
                $baseNames += $matches[1]
                if ($firstBaseLine -lt 0) {
                    $firstBaseLine = $i
                }
            }
        }

        $extrasNames.Count | Should -BeGreaterThan 0
        $baseNames.Count | Should -BeGreaterThan 0
        (($extrasNames -join "`n") -eq (($extrasNames | Sort-Object) -join "`n")) | Should -BeTrue
        (($baseNames -join "`n") -eq (($baseNames | Sort-Object) -join "`n")) | Should -BeTrue
        $lastExtrasLine | Should -BeLessThan $firstBaseLine
    }

    It 'Get-Git-Aliases -Base returns only base aliases' {
        $baseAliasesText = (Get-Git-Aliases -Base | Out-String)
        $baseAliasesText | Should -Match '(?im)^\s*ga\s+'
        $baseAliasesText | Should -Not -Match '(?im)^\s*grsh\s+'
    }

    It 'Get-Git-Aliases -Extras returns only extras aliases' {
        $extrasAliasesText = (Get-Git-Aliases -Extras | Out-String)
        $extrasAliasesText | Should -Match '(?im)^\s*grsh\s+'
        $extrasAliasesText | Should -Not -Match '(?im)^\s*gaa\s+'
    }

    It 'Get-Git-Aliases respects source filter for single alias lookup' {
        $extrasDefinition = Get-Git-Aliases -Alias grsh -Extras
        $extrasDefinition | Should -Match 'git reset --soft HEAD~1'

        { Get-Git-Aliases -Alias grsh -Base } | Should -Throw
    }
}

Describe 'gfp integration' {
    It 'creates series.mbox using default base branch resolution' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gfp-default-" + [guid]::NewGuid().Guid)
        $remotePath = Join-Path $tempRoot 'remote.git'
        $workPath = Join-Path $tempRoot 'work'

        New-Item -ItemType Directory -Path $workPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', '--bare', $remotePath) | Out-Null
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $workPath) | Out-Null

            Invoke-GitCommand -RepoPath $workPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $workPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $workPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('commit', '-m', 'init main') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('branch', '-M', 'main') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('remote', 'add', 'origin', $remotePath) | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('push', '-u', 'origin', 'main') | Out-Null

            Add-Content -Path (Join-Path $workPath 'README.md') -Value "`nfeature-from-main"
            Invoke-GitCommand -RepoPath $workPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('commit', '-m', 'feature main patch') | Out-Null

            Push-Location $workPath
            try {
                $mboxPath = gfp
            } finally {
                Pop-Location
            }

            $expectedPath = Join-Path $workPath 'series.mbox'
            $mboxPath | Should -Be $expectedPath
            (Test-Path -LiteralPath $expectedPath) | Should -BeTrue

            $mboxContent = Get-Content -LiteralPath $expectedPath -Raw
            $mboxContent | Should -Match 'Subject: \[PATCH'
            $mboxContent | Should -Match 'feature main patch'
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'supports explicit target branch and custom output mbox path' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gfp-custom-" + [guid]::NewGuid().Guid)
        $remotePath = Join-Path $tempRoot 'remote.git'
        $workPath = Join-Path $tempRoot 'work'

        New-Item -ItemType Directory -Path $workPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', '--bare', $remotePath) | Out-Null
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $workPath) | Out-Null

            Invoke-GitCommand -RepoPath $workPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $workPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $workPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('commit', '-m', 'init master') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('branch', '-M', 'master') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('remote', 'add', 'origin', $remotePath) | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('push', '-u', 'origin', 'master') | Out-Null

            Add-Content -Path (Join-Path $workPath 'README.md') -Value "`nfeature-custom"
            Invoke-GitCommand -RepoPath $workPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $workPath -Arguments @('commit', '-m', 'custom output patch') | Out-Null

            Push-Location $workPath
            try {
                $mboxPath = gfp master 'artifacts\custom-series.mbox'
            } finally {
                Pop-Location
            }

            $expectedPath = Join-Path $workPath 'artifacts\custom-series.mbox'
            $mboxPath | Should -Be $expectedPath
            (Test-Path -LiteralPath $expectedPath) | Should -BeTrue

            $mboxContent = Get-Content -LiteralPath $expectedPath -Raw
            $mboxContent | Should -Match 'Subject: \[PATCH'
            $mboxContent | Should -Match 'custom output patch'
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'gsw integration' {
    It 'completes branch names for gsw when command is followed by a space' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gsw-space-complete-" + [guid]::NewGuid().Guid)
        $repoPath = Join-Path $tempRoot 'repo'

        New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $repoPath) | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $repoPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('commit', '-m', 'init') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', '-M', 'main') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', 'feature/tab-complete') | Out-Null

            Push-Location $repoPath
            try {
                $line = 'gsw '
                $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            } finally {
                Pop-Location
            }

            $result.CompletionMatches.Count | Should -BeGreaterThan 0
            $completionTexts = @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText)
            $completionTexts | Should -Contain 'main'
            $completionTexts | Should -Contain 'feature/tab-complete'
            $completionTexts | Should -Not -Contain 'switch'
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'completes long options for gsw alias' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Push-Location $script:RepoRoot
        try {
            $result = Get-LongOptionCompletionResult -CommandName 'gsw' -FallbackPrefix '--t'
        } finally {
            Pop-Location
        }

        $result.CompletionMatches.Count | Should -BeGreaterThan 0
        $completionTexts = @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText)
        $completionTexts | Should -Contain '--track'
    }

    It 'completes long options for gco alias from git-aliases module' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue) -or -not $script:HasGcoAlias) {
        Push-Location $script:RepoRoot
        try {
            $result = Get-LongOptionCompletionResult -CommandName 'gco' -FallbackPrefix '--d'
        } finally {
            Pop-Location
        }

        $result.CompletionMatches.Count | Should -BeGreaterThan 0
        $completionTexts = @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText)
        $completionTexts | Should -Contain '--detach'
    }

    It 'returns PowerShell-safe completion text for branches starting with # when escaped prefix is used' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gsw-complete-" + [guid]::NewGuid().Guid)
        $repoPath = Join-Path $tempRoot 'repo'

        New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $repoPath) | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $repoPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('commit', '-m', 'init') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', '-M', 'main') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', '#8698') | Out-Null

            Push-Location $repoPath
            try {
                $line = 'gsw `#'
                $result = TabExpansion2 -inputScript $line -cursorColumn $line.Length
            } finally {
                Pop-Location
            }

            $result.CompletionMatches.Count | Should -BeGreaterThan 0
            $completionTexts = @($result.CompletionMatches | Select-Object -ExpandProperty CompletionText)
            $completionTexts | Should -Contain "'#8698'"
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'handles remote-only numeric branch when native switch is ambiguous' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gsw-integration-" + [guid]::NewGuid().Guid)
        $remotePath = Join-Path $tempRoot 'remote.git'
        $seedPath = Join-Path $tempRoot 'seed'
        $clonePath = Join-Path $tempRoot 'clone'

        New-Item -ItemType Directory -Path $seedPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', '--bare', $remotePath) | Out-Null
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $seedPath) | Out-Null

            Invoke-GitCommand -RepoPath $seedPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $seedPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('commit', '-m', 'init') | Out-Null
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('branch', '-M', 'main') | Out-Null
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('remote', 'add', 'origin', $remotePath) | Out-Null
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('push', '-u', 'origin', 'main') | Out-Null

            Invoke-GitCommand -RepoPath $seedPath -Arguments @('switch', '-c', '8695') | Out-Null
            Set-Content -Path (Join-Path $seedPath 'feature.txt') -Value 'feature' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('add', 'feature.txt') | Out-Null
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('commit', '-m', 'feature') | Out-Null
            Invoke-GitCommand -RepoPath $seedPath -Arguments @('push', '-u', 'origin', '8695') | Out-Null

            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('clone', $remotePath, $clonePath) | Out-Null
            Invoke-GitCommand -RepoPath $clonePath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            $collision = Find-BlobPrefixCollision -Prefix '8695'
            $collisionFile = Join-Path $clonePath 'collision.txt'
            Set-Content -Path $collisionFile -Value $collision.Content -NoNewline -Encoding ascii

            $written = (Invoke-GitCommand -RepoPath $clonePath -Arguments @('hash-object', '-w', $collisionFile)).Output
            $written | Should -Be $collision.Hash

            (Invoke-GitCommand -RepoPath $clonePath -Arguments @('cat-file', '-t', '8695')).Output | Should -Be 'blob'

            Push-Location $clonePath
            try {
                $previousPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                try {
                    $nativeSwitchOutput = & git switch 8695 2>&1 | Out-String
                    $nativeSwitchExitCode = $LASTEXITCODE
                } finally {
                    $ErrorActionPreference = $previousPreference
                }

                $nativeSwitchExitCode | Should -Not -Be 0
                $nativeSwitchOutput.Trim() | Should -Match 'unable to read tree|non-commit|invalid reference'

                $previousPreference = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                try {
                    gsw 8695 | Out-Null
                    $gswExitCode = $LASTEXITCODE
                } finally {
                    $ErrorActionPreference = $previousPreference
                }

                $gswExitCode | Should -Be 0
            } finally {
                Pop-Location
            }

            (Invoke-GitCommand -RepoPath $clonePath -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')).Output | Should -Be '8695'
            (Invoke-GitCommand -RepoPath $clonePath -Arguments @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')).Output | Should -Be 'origin/8695'
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'worktree aliases integration' {
    It 'provides worktree shortcuts and lists worktrees via gwtl' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gwt-shortcuts-" + [guid]::NewGuid().Guid)
        $repoPath = Join-Path $tempRoot 'repo'
        $worktreePath = Join-Path $tempRoot 'repo-feature'

        New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $repoPath) | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $repoPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('commit', '-m', 'init') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', '-M', 'main') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('worktree', 'add', '-b', 'feature/worktree', $worktreePath) | Out-Null

            Push-Location $repoPath
            try {
                $output = gwtl --porcelain | Out-String
            } finally {
                Pop-Location
            }

            $output | Should -Match 'worktree'
            $output | Should -Match ([regex]::Escape((Split-Path -Path $worktreePath -Leaf)))
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'completes worktree paths for gwtr and gwt remove' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gwt-complete-" + [guid]::NewGuid().Guid)
        $repoPath = Join-Path $tempRoot 'repo'
        $worktreePath = Join-Path $tempRoot 'repo-feature'

        New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $repoPath) | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $repoPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('commit', '-m', 'init') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', '-M', 'main') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('worktree', 'add', '-b', 'feature/worktree', $worktreePath) | Out-Null

            $expectedLeaf = Split-Path -Path $worktreePath -Leaf

            Push-Location $repoPath
            try {
                $gwtrLine = 'gwtr '
                $gwtrResult = TabExpansion2 -inputScript $gwtrLine -cursorColumn $gwtrLine.Length

                $gwtLine = 'gwt remove '
                $gwtResult = TabExpansion2 -inputScript $gwtLine -cursorColumn $gwtLine.Length
            } finally {
                Pop-Location
            }

            $gwtrResult.CompletionMatches.Count | Should -BeGreaterThan 0
            $gwtrTexts = @($gwtrResult.CompletionMatches | Select-Object -ExpandProperty CompletionText)
            (@($gwtrTexts | Where-Object { $_ -like "*$expectedLeaf*" })).Count | Should -BeGreaterThan 0

            $gwtResult.CompletionMatches.Count | Should -BeGreaterThan 0
            $gwtTexts = @($gwtResult.CompletionMatches | Select-Object -ExpandProperty CompletionText)
            (@($gwtTexts | Where-Object { $_ -like "*$expectedLeaf*" })).Count | Should -BeGreaterThan 0
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'creates auto worktree path for branch-only gwta invocation' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gwta-auto-path-" + [guid]::NewGuid().Guid)
        $repoPath = Join-Path $tempRoot 'repo'

        New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $repoPath) | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $repoPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('commit', '-m', 'init') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', '-M', 'main') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', '8698') | Out-Null

            Push-Location $repoPath
            try {
                gwta 8698 | Out-Null
            } finally {
                Pop-Location
            }

            $porcelainText = (Invoke-GitCommand -RepoPath $repoPath -Arguments @('worktree', 'list', '--porcelain')).Output
            $worktreePaths = @(
                $porcelainText -split "`r?`n" |
                Where-Object { $_ -like 'worktree *' } |
                ForEach-Object { $_.Substring(9).Trim() }
            )

            $repoFullPath = [IO.Path]::GetFullPath($repoPath)
            $linkedWorktreePath = @($worktreePaths | Where-Object { [IO.Path]::GetFullPath($_) -ne $repoFullPath })[0]
            $linkedWorktreePath | Should -Not -BeNullOrEmpty

            $baseRoot = if ($env:GIT_ALIASES_EXTRA_WORKTREE_ROOT) {
                $env:GIT_ALIASES_EXTRA_WORKTREE_ROOT
            } elseif ($env:LOCALAPPDATA) {
                Join-Path $env:LOCALAPPDATA 'git-worktrees'
            } else {
                Join-Path ([IO.Path]::GetTempPath()) 'git-worktrees'
            }

            $expectedRoot = Join-Path $baseRoot (Split-Path -Path $repoPath -Leaf)
            [IO.Path]::GetFullPath($linkedWorktreePath) | Should -Match ([regex]::Escape([IO.Path]::GetFullPath($expectedRoot)))
            (Invoke-GitCommand -RepoPath $linkedWorktreePath -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')).Output | Should -Be '8698'
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'creates auto worktree path for gwta -b invocation without explicit path' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gwta-auto-path-create-" + [guid]::NewGuid().Guid)
        $repoPath = Join-Path $tempRoot 'repo'

        New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $repoPath) | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $repoPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('commit', '-m', 'init') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', '-M', 'main') | Out-Null

            Push-Location $repoPath
            try {
                gwta -b feature/new-worktree | Out-Null
            } finally {
                Pop-Location
            }

            $porcelainText = (Invoke-GitCommand -RepoPath $repoPath -Arguments @('worktree', 'list', '--porcelain')).Output
            $worktreePaths = @(
                $porcelainText -split "`r?`n" |
                Where-Object { $_ -like 'worktree *' } |
                ForEach-Object { $_.Substring(9).Trim() }
            )

            $repoFullPath = [IO.Path]::GetFullPath($repoPath)
            $linkedWorktreePath = @($worktreePaths | Where-Object { [IO.Path]::GetFullPath($_) -ne $repoFullPath })[0]
            $linkedWorktreePath | Should -Not -BeNullOrEmpty

            $baseRoot = if ($env:GIT_ALIASES_EXTRA_WORKTREE_ROOT) {
                $env:GIT_ALIASES_EXTRA_WORKTREE_ROOT
            } elseif ($env:LOCALAPPDATA) {
                Join-Path $env:LOCALAPPDATA 'git-worktrees'
            } else {
                Join-Path ([IO.Path]::GetTempPath()) 'git-worktrees'
            }

            $expectedRoot = Join-Path $baseRoot (Split-Path -Path $repoPath -Leaf)
            [IO.Path]::GetFullPath($linkedWorktreePath) | Should -Match ([regex]::Escape([IO.Path]::GetFullPath($expectedRoot)))
            (Invoke-GitCommand -RepoPath $linkedWorktreePath -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')).Output | Should -Be 'feature/new-worktree'
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    It 'completes branch names for gwta and gwt add branch positions (including after -f)' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("gwta-branch-complete-" + [guid]::NewGuid().Guid)
        $repoPath = Join-Path $tempRoot 'repo'

        New-Item -ItemType Directory -Path $repoPath -Force | Out-Null
        try {
            Invoke-GitCommand -RepoPath $tempRoot -Arguments @('init', $repoPath) | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.email', 'test@example.com') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'user.name', 'Test User') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('config', 'commit.gpgsign', 'false') | Out-Null

            Set-Content -Path (Join-Path $repoPath 'README.md') -Value 'root' -NoNewline -Encoding ascii
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('add', 'README.md') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('commit', '-m', 'init') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', '-M', 'main') | Out-Null
            Invoke-GitCommand -RepoPath $repoPath -Arguments @('branch', 'feature/worktree') | Out-Null

            Push-Location $repoPath
            try {
                $gwtaBranchLine = 'gwta -b '
                $gwtaBranchResult = TabExpansion2 -inputScript $gwtaBranchLine -cursorColumn $gwtaBranchLine.Length

                $gwtaStartPointLine = 'gwta ..\repo-feature '
                $gwtaStartPointResult = TabExpansion2 -inputScript $gwtaStartPointLine -cursorColumn $gwtaStartPointLine.Length

                $gwtaForceLine = 'gwta ..\repo-feature -f '
                $gwtaForceResult = TabExpansion2 -inputScript $gwtaForceLine -cursorColumn $gwtaForceLine.Length

                $gwtStartPointLine = 'gwt add ..\repo-feature '
                $gwtStartPointResult = TabExpansion2 -inputScript $gwtStartPointLine -cursorColumn $gwtStartPointLine.Length

                $gwtForceLine = 'gwt add ..\repo-feature -f '
                $gwtForceResult = TabExpansion2 -inputScript $gwtForceLine -cursorColumn $gwtForceLine.Length
            } finally {
                Pop-Location
            }

            $gwtaBranchResult.CompletionMatches.Count | Should -BeGreaterThan 0
            $gwtaBranchTexts = @($gwtaBranchResult.CompletionMatches | Select-Object -ExpandProperty CompletionText)
            $gwtaBranchTexts | Should -Contain 'main'

            $gwtaStartPointResult.CompletionMatches.Count | Should -BeGreaterThan 0
            $gwtaStartPointTexts = @($gwtaStartPointResult.CompletionMatches | Select-Object -ExpandProperty CompletionText)
            $gwtaStartPointTexts | Should -Contain 'main'
            $gwtaStartPointTexts | Should -Contain 'feature/worktree'

            $gwtStartPointResult.CompletionMatches.Count | Should -BeGreaterThan 0
            $gwtStartPointTexts = @($gwtStartPointResult.CompletionMatches | Select-Object -ExpandProperty CompletionText)
            $gwtStartPointTexts | Should -Contain 'main'
            $gwtStartPointTexts | Should -Contain 'feature/worktree'

            $gwtaForceResult.CompletionMatches.Count | Should -BeGreaterThan 0
            $gwtaForceTexts = @($gwtaForceResult.CompletionMatches | Select-Object -ExpandProperty CompletionText)
            $gwtaForceTexts | Should -Contain 'main'
            $gwtaForceTexts | Should -Contain 'feature/worktree'

            $gwtForceResult.CompletionMatches.Count | Should -BeGreaterThan 0
            $gwtForceTexts = @($gwtForceResult.CompletionMatches | Select-Object -ExpandProperty CompletionText)
            $gwtForceTexts | Should -Contain 'main'
            $gwtForceTexts | Should -Contain 'feature/worktree'
        } finally {
            if (Test-Path $tempRoot) {
                Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
