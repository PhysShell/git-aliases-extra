# ===================================================================
# git-aliases-extra.psm1
#
# Extends posh-git and git-aliases with custom functions and
# adds robust tab completion for all git aliases.
#
# Mainly inspired by: https://github.com/zh30/zsh-shortcut-git
# ===================================================================

# --- Custom Helper Functions ---
function Test-InGitRepo {
    try {
        git rev-parse --is-inside-work-tree *> $null
        $true
    } catch {
        $false
    }
}

function Test-GitInProgress {
    if (-not (Test-InGitRepo)) { return $false }
    $gitDir = git rev-parse --git-dir
    $inProgressFiles = @("MERGE_HEAD", "REBASE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "BISECT_LOG")
    foreach ($file in $inProgressFiles) {
        if (Test-Path (Join-Path $gitDir $file)) { return $true }
    }
    $false
}

function Test-WorkingTreeClean {
    if (-not (Test-InGitRepo)) { return $false }
    # Checks for both unstaged and staged changes.
    & git diff --quiet --exit-code
    $isClean = ($LASTEXITCODE -eq 0)
    & git diff --cached --quiet --exit-code
    $isClean = $isClean -and ($LASTEXITCODE -eq 0)
    return $isClean
}

function Get-CurrentBranch {
    if (Test-InGitRepo) {
        $branch = git rev-parse --abbrev-ref HEAD
        if ($branch -ne "HEAD") {
            return $branch.Trim()
        }
    }
    return $null
}

function Test-GitRefExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RefName
    )
    & git show-ref --verify --quiet $RefName
    return ($LASTEXITCODE -eq 0)
}

function Convert-ToPowerShellBranchCompletionText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BranchName
    )

    if ($BranchName.StartsWith('#')) {
        $escaped = $BranchName -replace "'", "''"
        return "'$escaped'"
    }

    return $BranchName
}

function Get-GitLongOptionCompletions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubCommandLine,
        [Parameter(Mandatory = $true)]
        [string]$WordToComplete
    )

    if (-not $WordToComplete.StartsWith('-')) {
        return @()
    }

    try {
        $commandParts = @($SubCommandLine -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($commandParts.Count -eq 0) { return @() }

        $helpText = (& git @commandParts -h 2>&1 | Out-String)
        if (-not $helpText) { return @() }

        $rawTokens = [regex]::Matches($helpText, '--[^\s,]+') |
                    ForEach-Object { $_.Value } |
                    Sort-Object -Unique

        $expanded = foreach ($token in $rawTokens) {
            $clean = $token.Trim().TrimEnd(',', ';')
            $clean = $clean -replace '<.*$', ''

            if ($clean -match '^--\[no-\](.+)$') {
                $suffix = $matches[1] -replace '\[.*$', ''
                if ($suffix) {
                    "--$suffix"
                    "--no-$suffix"
                }
                continue
            }

            $clean = $clean -replace '\[.*$', ''
            if ($clean.StartsWith('--')) {
                $clean
            }
        }

        $options = $expanded |
                   Sort-Object -Unique |
                   Where-Object { $_ -like "$WordToComplete*" }

        if (-not $options) { return @() }

        return $options | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterName', $_)
        }
    } catch {
        return @()
    }
}

function Format-GitAliasDefinitionSafe {
    param(
        [AllowEmptyString()]
        [string]$Definition
    )

    if ([string]::IsNullOrWhiteSpace($Definition)) {
        return ''
    }

    $definitionLines = $Definition.Trim() -split "`r?`n" | ForEach-Object {
        $rawLine = [string]$_
        $line = $rawLine.TrimEnd()
        if ($rawLine -match "^`t") {
            if ($line.Length -ge 1) {
                return $line.Substring(1)
            }

            return ''
        }
        if ($rawLine -match '^    ') {
            if ($line.Length -ge 4) {
                return $line.Substring(4)
            }

            return ''
        }

        return $line
    }

    return ($definitionLines -join "`n")
}

function Convert-ToPowerShellPathCompletionText {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PathValue
    )

    if ($PathValue -match "[\s']") {
        $escaped = $PathValue -replace "'", "''"
        return "'$escaped'"
    }

    return $PathValue
}

function Convert-ToWorktreePathSegment {
    param(
        [AllowEmptyString()]
        [string]$Text
    )

    if ($null -eq $Text) {
        $Text = ''
    }

    $segment = $Text.Trim("'", '"').Trim()
    $segment = $segment -replace '[\\/]+', '-'
    $segment = $segment -replace '[<>:"|?*]', '-'
    $segment = $segment.Trim('.', ' ')

    if ([string]::IsNullOrWhiteSpace($segment)) {
        return 'worktree'
    }

    return $segment
}

function Get-GitWorktreeAutoRoot {
    if ($env:GIT_ALIASES_EXTRA_WORKTREE_ROOT) {
        $root = $env:GIT_ALIASES_EXTRA_WORKTREE_ROOT
    } elseif ($env:LOCALAPPDATA) {
        $root = Join-Path $env:LOCALAPPDATA 'git-worktrees'
    } else {
        $root = Join-Path ([IO.Path]::GetTempPath()) 'git-worktrees'
    }

    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }

    try {
        $topLevel = (& git rev-parse --show-toplevel 2>$null | Out-String).Trim()
        if ($LASTEXITCODE -eq 0 -and $topLevel) {
            $repoSegment = Convert-ToWorktreePathSegment -Text (Split-Path -Path $topLevel -Leaf)
            $root = Join-Path $root $repoSegment
            if (-not (Test-Path -LiteralPath $root)) {
                New-Item -ItemType Directory -Path $root -Force | Out-Null
            }
        }
    } catch {
        Write-Verbose ("Get-GitWorktreeAutoRoot fallback used: {0}" -f $_.Exception.Message)
    }

    return (Resolve-Path -LiteralPath $root | Select-Object -ExpandProperty Path -First 1)
}

function Get-GitWorktreeAutoPath {
    param(
        [AllowEmptyString()]
        [string]$Hint
    )

    $root = Get-GitWorktreeAutoRoot
    $baseName = Convert-ToWorktreePathSegment -Text $Hint
    $candidate = Join-Path $root $baseName
    $suffix = 2

    while (Test-Path -LiteralPath $candidate) {
        $candidate = Join-Path $root ("{0}-{1}" -f $baseName, $suffix)
        $suffix++
    }

    return $candidate
}

function Test-LooksLikeWorktreePathToken {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Token
    )

    $trimmed = $Token.Trim("'", '"')
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        return $false
    }

    if ($trimmed -match '^[A-Za-z]:[\\/]') { return $true }
    if ($trimmed.StartsWith('.\') -or $trimmed.StartsWith('..\')) { return $true }
    if ($trimmed.StartsWith('./') -or $trimmed.StartsWith('../')) { return $true }
    if ($trimmed.StartsWith('\') -or $trimmed.StartsWith('/')) { return $true }
    if ($trimmed.StartsWith('~\') -or $trimmed.StartsWith('~/')) { return $true }
    if ($trimmed.Contains('\')) { return $true }
    if (Test-Path -LiteralPath $trimmed) { return $true }

    return $false
}

function Get-GitBranchCompletions {
    param(
        [AllowEmptyString()]
        [string]$WordToComplete
    )

    if (-not (Test-InGitRepo)) {
        return @()
    }

    $prefix = $WordToComplete.Trim("'", '"')
    if ($prefix.StartsWith('`')) {
        $prefix = $prefix.Substring(1)
    }

    try {
        $branches = @(
            git branch -a --format='%(refname:short)' |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $_ -replace '^remotes/origin/', '' } |
            Where-Object { $_ -ne 'HEAD' } |
            Sort-Object -Unique
        )

        if (-not [string]::IsNullOrWhiteSpace($prefix)) {
            $branches = @($branches | Where-Object { $_ -like "$prefix*" })
        }

        if (-not $branches -or $branches.Count -eq 0) {
            return @()
        }

        return @($branches | ForEach-Object {
            $branchName = [string]$_
            $safeText = Convert-ToPowerShellBranchCompletionText -BranchName $branchName
            [System.Management.Automation.CompletionResult]::new($safeText, $branchName, 'ParameterValue', $branchName)
        })
    } catch {
        return @()
    }
}

function Get-GitWorktreePaths {
    if (-not (Test-InGitRepo)) {
        return @()
    }

    try {
        $lines = @(& git worktree list --porcelain 2>$null)
        if ($LASTEXITCODE -ne 0 -or -not $lines) {
            return @()
        }

        $paths = $lines |
            Where-Object { $_ -like 'worktree *' } |
            ForEach-Object { $_.Substring(9).Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Sort-Object -Unique

        return @($paths)
    } catch {
        return @()
    }
}

function Get-GitWorktreePathCompletions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        [Parameter(Mandatory = $true)]
        [string]$Line,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$WordToComplete
    )

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($Line, [ref]$tokens, [ref]$errors) | Out-Null
    $tokenTexts = @(
        $tokens |
        Where-Object { $_.Kind.ToString() -notin @('EndOfInput', 'NewLine') } |
        ForEach-Object { $_.Text }
    )

    if ($tokenTexts.Count -eq 0) {
        return @()
    }

    $action = ''
    $argumentTokens = @()

    switch ($CommandName) {
        'gwtr' {
            $action = 'remove'
            if ($tokenTexts.Count -gt 1) {
                $argumentTokens = @($tokenTexts[1..($tokenTexts.Count - 1)])
            }
        }
        'gwtm' {
            $action = 'move'
            if ($tokenTexts.Count -gt 1) {
                $argumentTokens = @($tokenTexts[1..($tokenTexts.Count - 1)])
            }
        }
        'gwt' {
            if ($tokenTexts.Count -lt 2) {
                return @()
            }

            $action = $tokenTexts[1]
            if ($tokenTexts.Count -gt 2) {
                $argumentTokens = @($tokenTexts[2..($tokenTexts.Count - 1)])
            }
        }
        default {
            return @()
        }
    }

    if ($action -notin @('remove', 'move')) {
        return @()
    }

    $nonOptionArgCount = @($argumentTokens | Where-Object { -not $_.StartsWith('-') }).Count
    $hasWord = -not [string]::IsNullOrWhiteSpace($WordToComplete)
    $completeFirstPath = $nonOptionArgCount -eq 0 -or ($nonOptionArgCount -eq 1 -and $hasWord)
    if (-not $completeFirstPath) {
        return @()
    }

    $prefix = $WordToComplete.Trim("'", '"')
    $worktreePaths = Get-GitWorktreePaths
    if (-not $worktreePaths -or $worktreePaths.Count -eq 0) {
        return @()
    }

    $filteredPaths = if ([string]::IsNullOrWhiteSpace($prefix)) {
        $worktreePaths
    } else {
        $worktreePaths | Where-Object {
            $_ -like "$prefix*" -or (Split-Path -Path $_ -Leaf) -like "$prefix*"
        }
    }

    if (-not $filteredPaths) {
        return @()
    }

    return @($filteredPaths | Sort-Object -Unique | ForEach-Object {
        $pathValue = [string]$_
        $completionText = Convert-ToPowerShellPathCompletionText -PathValue $pathValue
        [System.Management.Automation.CompletionResult]::new(
            $completionText,
            $pathValue,
            'ParameterValue',
            "git worktree path: $pathValue"
        )
    })
}

function Get-GitWorktreeAddBranchCompletions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        [Parameter(Mandatory = $true)]
        [string]$Line,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$WordToComplete
    )

    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseInput($Line, [ref]$tokens, [ref]$errors) | Out-Null
    $tokenTexts = @(
        $tokens |
        Where-Object { $_.Kind.ToString() -notin @('EndOfInput', 'NewLine') } |
        ForEach-Object { $_.Text }
    )

    if ($tokenTexts.Count -eq 0) {
        return @()
    }

    $argumentTokens = @()
    switch ($CommandName) {
        'gwta' {
            if ($tokenTexts.Count -gt 1) {
                $argumentTokens = @($tokenTexts[1..($tokenTexts.Count - 1)])
            }
        }
        'gwt' {
            if ($tokenTexts.Count -lt 2 -or $tokenTexts[1] -ne 'add') {
                return @()
            }
            if ($tokenTexts.Count -gt 2) {
                $argumentTokens = @($tokenTexts[2..($tokenTexts.Count - 1)])
            }
        }
        default {
            return @()
        }
    }

    $endsWithWhitespace = $Line -match '\s$'
    $analysisTokens = @($argumentTokens)
    if (-not $endsWithWhitespace -and $analysisTokens.Count -gt 0) {
        $analysisTokens = @($analysisTokens[0..($analysisTokens.Count - 2)])
    }

    $expectValueFor = ''
    $positionalCount = 0
    foreach ($token in $analysisTokens) {
        if ($expectValueFor) {
            $expectValueFor = ''
            continue
        }

        switch ($token) {
            '-b' { $expectValueFor = 'branch'; continue }
            '-B' { $expectValueFor = 'branch'; continue }
            '--reason' { $expectValueFor = 'reason'; continue }
        }

        if ($token.StartsWith('-')) {
            continue
        }

        $positionalCount++
    }

    if ($expectValueFor -eq 'branch' -or $positionalCount -ge 1) {
        return Get-GitBranchCompletions -WordToComplete $WordToComplete
    }

    return @()
}

function Get-GitWorktreeCompletions {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName,
        [Parameter(Mandatory = $true)]
        [string]$Line,
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$WordToComplete
    )

    if ($WordToComplete -like '-*') {
        return @()
    }

    $pathCompletions = Get-GitWorktreePathCompletions `
        -CommandName $CommandName `
        -Line $Line `
        -WordToComplete $WordToComplete
    if ($pathCompletions -and $pathCompletions.Count -gt 0) {
        return $pathCompletions
    }

    $branchCompletions = Get-GitWorktreeAddBranchCompletions `
        -CommandName $CommandName `
        -Line $Line `
        -WordToComplete $WordToComplete
    if ($branchCompletions -and $branchCompletions.Count -gt 0) {
        return $branchCompletions
    }

    return @()
}

function Get-GitAliasEntries {
    param(
        [ValidateSet('all', 'base', 'extras')]
        [string]$Source = 'all'
    )

    $blacklist = @(
        'Get-Git-CurrentBranch',
        'Remove-Alias',
        'Format-AliasDefinition',
        'Get-Git-Aliases',
        'Write-Host-Deprecated',
        'Format-GitAliasDefinitionSafe',
        'Get-GitAliasEntries'
    )

    $modulePriority = @{
        'git-aliases-extra' = 0
        'git-aliases'       = 1
    }
    $moduleSource = @{
        'git-aliases-extra' = 'extras'
        'git-aliases'       = 'base'
    }

    $entries = @()
    $aliasNamePattern = '^g[0-9A-Za-z!]+$'
    foreach ($moduleName in @('git-aliases-extra', 'git-aliases')) {
        $commands = Get-Command -Module $moduleName -ErrorAction SilentlyContinue |
            Where-Object {
                $_.Name -notin $blacklist -and
                $_.CommandType -in @('Function', 'Alias') -and
                $_.Name -match $aliasNamePattern
            }

        foreach ($command in $commands) {
            $definition = switch ($command.CommandType) {
                'Alias' { "Alias -> $($command.Definition)" }
                default { Format-GitAliasDefinitionSafe -Definition $command.Definition }
            }

            if ([string]::IsNullOrWhiteSpace($definition)) {
                continue
            }

            $entries += [PSCustomObject]@{
                Name       = $command.Name
                Definition = $definition
                ModuleName = $moduleName
                Source     = $moduleSource[$moduleName]
                Priority   = $modulePriority[$moduleName]
            }
        }
    }

    if ($Source -ne 'all') {
        return $entries |
            Where-Object { $_.Source -eq $Source } |
            Sort-Object Name
    }

    $ordered = $entries | Sort-Object Priority, Name
    $seen = @{}
    $result = foreach ($entry in $ordered) {
        if (-not $seen.ContainsKey($entry.Name)) {
            $seen[$entry.Name] = $true
            $entry
        }
    }

    return @($result)
}

function Get-Git-Aliases {
    [CmdletBinding()]
    param(
        [AllowEmptyString()]
        [string]$Alias,
        [switch]$Base,
        [switch]$Extras
    )

    if ($Base -and $Extras) {
        Write-Error "Use either -Base or -Extras, not both." -ErrorAction Stop
    }

    $source = 'all'
    if ($Base) { $source = 'base' }
    if ($Extras) { $source = 'extras' }

    $Alias = if ($null -eq $Alias) { '' } else { $Alias.Trim() }
    $aliases = Get-GitAliasEntries -Source $source

    if (-not ([string]::IsNullOrWhiteSpace($Alias))) {
        $foundAlias = $aliases | Where-Object { $_.Name -eq $Alias } | Select-Object -First 1
        if ($null -eq $foundAlias) {
            $scopeText = switch ($source) {
                'base' { ' in base aliases' }
                'extras' { ' in extras aliases' }
                default { '' }
            }
            Write-Error ("Alias '{0}' not found{1}." -f $Alias, $scopeText) -ErrorAction Stop
        }

        return $foundAlias.Definition
    }

    if ($source -in @('base', 'extras')) {
        return $aliases |
            Select-Object Name, Definition |
            Format-Table -AutoSize -Wrap
    }

    return $aliases |
        Select-Object Name, Source, Definition |
        Format-Table -AutoSize -Wrap
}


# --- Custom Git Command Functions ---
function UpMerge {
    [CmdletBinding()]
    param(
        [string]$Src = "origin/main",
        [switch]$AllowDirty, [switch]$AllowInProgress, [switch]$NoFetch, [switch]$NoFF
    )
    if (-not (Test-InGitRepo)) { throw "Not a git repository." }
    $tgt = Get-CurrentBranch; if (-not $tgt) { throw "Detached HEAD. Cannot merge." }
    if (-not $AllowInProgress -and (Test-GitInProgress)) { throw "Another git operation is in progress." }
    if (-not $AllowDirty -and -not (Test-WorkingTreeClean)) { throw "Working tree is not clean." }
    if (-not $NoFetch) { git fetch --all --prune; if ($LASTEXITCODE -ne 0) { throw "git fetch failed." } }
    $msg = "chore(sync): merge $Src into $tgt"
    if ($NoFF) { git merge --no-ff --no-edit $Src -m $msg } else { git merge --no-edit $Src -m $msg }
}

function UpRebase {
    [CmdletBinding()]
    param(
        [string]$Src = "origin/main",
        [switch]$AllowDirty, [switch]$AllowInProgress, [switch]$NoFetch, [switch]$Autostash
    )
    if (-not (Test-InGitRepo)) { throw "Not a git repository." }
    $tgt = Get-CurrentBranch; if (-not $tgt) { throw "Detached HEAD. Cannot rebase." }
    if (-not $AllowInProgress -and (Test-GitInProgress)) { throw "Another git operation is in progress." }
    if (-not $AllowDirty -and -not (Test-WorkingTreeClean)) { throw "Working tree is not clean." }
    if (-not $NoFetch) { git fetch --all --prune; if ($LASTEXITCODE -ne 0) { throw "git fetch failed." } }
    if ($Autostash) { git rebase --autostash $Src } else { git rebase $Src }
}

function gapt   { git apply --3way @args }
function gcor   { git checkout --recurse-submodules @args }
function gdct   { git describe --tags (git rev-list --tags --max-count=1) }
function gdt    { git diff-tree --no-commit-id --name-only -r @args }
function gdnolock { git diff @args ":(exclude)package-lock.json" ":(exclude)*.lock" }
function gdv    { git diff -w @args | Out-String | less }
function gfo    { git fetch origin @args }
function gwt    { git worktree @args }
function gwta {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$rest
    )

    if ($null -eq $rest) {
        $rest = @()
    }

    if (-not (Test-InGitRepo)) {
        git worktree add @rest
        return
    }

    $positionalIndices = @()
    $positionalTokens = @()
    $createBranchName = ''
    $hasCreateBranchOption = $false
    $expectValueFor = ''

    for ($i = 0; $i -lt $rest.Count; $i++) {
        $token = [string]$rest[$i]
        if ($expectValueFor) {
            if ($expectValueFor -eq 'create-branch') {
                $createBranchName = $token.Trim("'", '"')
                $hasCreateBranchOption = $true
            }
            $expectValueFor = ''
            continue
        }

        switch ($token) {
            '-b' { $expectValueFor = 'create-branch'; continue }
            '-B' { $expectValueFor = 'create-branch'; continue }
            '--reason' { $expectValueFor = 'reason'; continue }
        }

        if ($token.StartsWith('-')) {
            continue
        }

        $positionalIndices += $i
        $positionalTokens += $token
    }

    $autoPathHint = ''
    $insertBeforeIndex = -1

    # Convenience modes:
    # - `gwta <branch>` creates a worktree under LOCALAPPDATA\git-worktrees\<repo>\<branch>.
    # - `gwta -b <new-branch>` does the same when path is omitted.
    if ($hasCreateBranchOption -and $positionalTokens.Count -eq 0) {
        $autoPathHint = if ($createBranchName) { $createBranchName } else { Get-CurrentBranch }
        $insertBeforeIndex = $rest.Count
    } elseif (-not $hasCreateBranchOption -and
              $positionalTokens.Count -eq 1 -and
              -not (Test-LooksLikeWorktreePathToken -Token $positionalTokens[0])) {
        $autoPathHint = $positionalTokens[0]
        $insertBeforeIndex = [int]$positionalIndices[0]
    }

    if (-not $autoPathHint) {
        git worktree add @rest
        return
    }

    $autoPath = Get-GitWorktreeAutoPath -Hint $autoPathHint
    $prefixArgs = @()
    $suffixArgs = @()
    if ($insertBeforeIndex -gt 0) {
        $prefixArgs = @($rest[0..($insertBeforeIndex - 1)])
    }
    if ($insertBeforeIndex -lt $rest.Count) {
        $suffixArgs = @($rest[$insertBeforeIndex..($rest.Count - 1)])
    }

    $gitArgs = @('worktree', 'add') + $prefixArgs + @($autoPath) + $suffixArgs
    Write-Verbose ("gwta auto path: {0}" -f $autoPath)
    & git @gitArgs
}
function gwtl   { git worktree list @args }
function gwtm   { git worktree move @args }
function gwtr   { git worktree remove @args }
function gwtp   { git worktree prune @args }
function glp    { param([string]$format) if($format){ git log --pretty=$format } else { git log } }
function gmtl   { git mergetool --no-prompt @args }
function gmtlvim{ git mergetool --no-prompt --tool=vimdiff @args }
function gtv    { git tag | Sort-Object { $_ -as [version] } }
function gtl    { param($p='') git tag --sort=-v:refname -n -l "$p*" }
function gwip   { git add -A; git rm (git ls-files --deleted) 2>$null; git commit --no-verify --no-gpg-sign -m "--wip-- [skip ci]" }
function gunwip { if (git log -n 1 | Select-String -Quiet -- "--wip--") { git reset HEAD~1 } }

function grsh { git reset --soft HEAD~1 }
function gccd   {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$rest)
    git clone --recurse-submodules @rest
    $last = if ($rest.Count) { $rest[-1] } else { '' }
    if ($last -match '\.git$') { $last = $last -replace '\.git$','' }
    if ($last) {
      $dirName = Split-Path $last -Leaf
      if (Test-Path $dirName) {
        Set-Location $dirName
      }
    }
}
function grl    { git reflog @args }

# Get commit hash - returns the hash of HEAD or HEAD~n
# Usage: ghash [steps] [-Short]
#   ghash          - full hash of HEAD
#   ghash 3        - full hash of HEAD~3
#   ghash -Short   - short hash of HEAD
#   ghash 3 -Short - short hash of HEAD~3
function ghash {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [int]$StepsBack = 0,
        [Alias('s')]
        [switch]$Short
    )
    
    if (-not (Test-InGitRepo)) {
        Write-Error "Not a git repository." -ErrorAction Stop
        return
    }
    
    $ref = if ($StepsBack -eq 0) { "HEAD" } else { "HEAD~$StepsBack" }
    
    try {
        if ($Short) {
            $hash = git rev-parse --short $ref 2>$null
        } else {
            $hash = git rev-parse $ref 2>$null
        }
        
        if ($LASTEXITCODE -eq 0 -and $hash) {
            $hash.Trim()
        } else {
            Write-Error "Invalid reference: $ref" -ErrorAction Stop
        }
    } catch {
        Write-Error "Failed to get commit hash: $_" -ErrorAction Stop
    }
}

function gfp {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$TargetBranch,
        [Parameter(Position = 1)]
        [string]$OutputFile = 'series.mbox'
    )

    if (-not (Test-InGitRepo)) {
        throw "Not a git repository."
    }

    $defaultRemote = git config --get checkout.defaultRemote 2>$null
    if (-not $defaultRemote) { $defaultRemote = 'origin' }

    if (-not $TargetBranch) {
        if (Test-GitRefExists "refs/remotes/$defaultRemote/main") {
            $TargetBranch = 'main'
        } elseif (Test-GitRefExists "refs/remotes/$defaultRemote/master") {
            $TargetBranch = 'master'
        } else {
            $remoteHead = git symbolic-ref --quiet "refs/remotes/$defaultRemote/HEAD" 2>$null
            if ($LASTEXITCODE -eq 0 -and $remoteHead) {
                $prefix = "refs/remotes/$defaultRemote/"
                if ($remoteHead.StartsWith($prefix)) {
                    $TargetBranch = $remoteHead.Substring($prefix.Length).Trim()
                }
            }
        }

        if (-not $TargetBranch) { $TargetBranch = 'main' }
    }

    $range = "$defaultRemote/$TargetBranch..HEAD"
    $resolvedOutput = if ([IO.Path]::IsPathRooted($OutputFile)) {
        $OutputFile
    } else {
        Join-Path (Get-Location) $OutputFile
    }

    $outputDir = Split-Path -Parent $resolvedOutput
    if ($outputDir -and -not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $stderrFile = [IO.Path]::GetTempFileName()
    try {
        $process = Start-Process -FilePath 'git' `
            -ArgumentList @('format-patch', '--cover-letter', '--stat', '--stdout', $range) `
            -NoNewWindow `
            -PassThru `
            -Wait `
            -RedirectStandardOutput $resolvedOutput `
            -RedirectStandardError $stderrFile

        $stderrText = Get-Content -LiteralPath $stderrFile -Raw -ErrorAction SilentlyContinue
        if ($stderrText) {
            $stderrText = $stderrText.Trim()
            if ($stderrText) {
                Write-Host $stderrText
            }
        }

        if ($process.ExitCode -ne 0) {
            Remove-Item -LiteralPath $resolvedOutput -Force -ErrorAction SilentlyContinue
            throw "git format-patch failed for '$range' (exit code: $($process.ExitCode))."
        }

        return $resolvedOutput
    } finally {
        Remove-Item -LiteralPath $stderrFile -Force -ErrorAction SilentlyContinue
    }
}

function gsw {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]]$rest
    )

    # Keep native behavior for advanced invocations (flags, start-points, etc.).
    if ($rest.Count -ne 1 -or $rest[0].StartsWith('-')) {
        git switch @rest
        return
    }

    if (-not (Test-InGitRepo)) {
        git switch @rest
        return
    }

    $target = $rest[0].Trim()
    if (-not $target) {
        git switch @rest
        return
    }

    # Prefer an existing local branch first.
    if (Test-GitRefExists "refs/heads/$target") {
        git switch $target
        return
    }

    # If only remote exists, create a tracking local branch explicitly.
    # This avoids ambiguous SHA/ref parsing for numeric names like "8695".
    $defaultRemote = git config --get checkout.defaultRemote 2>$null
    if (-not $defaultRemote) { $defaultRemote = 'origin' }
    if (Test-GitRefExists "refs/remotes/$defaultRemote/$target") {
        git switch --track "$defaultRemote/$target"
        return
    }

    git switch @rest
}

function gswc    { git switch -c @args }

# Alias for shorter command

# --- Set Aliases for Custom Functions ---
Set-Alias gum UpMerge
Set-Alias gur UpRebase
Set-Alias gh ghash


# ===================================================================
# Tab Completion Registration
# ===================================================================
function Register-GitAliasCompletion {
    # 1. Build a map of alias functions to their git subcommands
    $script:gitAliasMap = @{}
    $aliasRegex = '^\s*git\s+([\w-]+)\s+'

    # Get all aliases from the 'git-aliases' module
    Get-Command -Module git-aliases | ForEach-Object {
        $definition = (Get-Content Function:\$($_.Name)).ToString()
        if ($definition -match $aliasRegex) {
            $script:gitAliasMap[$_.Name] = $matches[1]
        }
    }

    # Add custom aliases from this module without module-name lookups
    # to avoid self-import recursion during module initialization.
    $moduleName = $ExecutionContext.SessionState.Module.Name
    Get-Command -CommandType Function |
    Where-Object { $_.ModuleName -eq $moduleName } |
    ForEach-Object {
        $func = $_
        $definition = $func.ScriptBlock.ToString()
        if ($definition -match $aliasRegex) {
            $subCommand = $matches[1]
            $script:gitAliasMap[$func.Name] = $subCommand
        }
    }

    # Manually add complex functions that don't fit the regex pattern
    $script:gitAliasMap['gum'] = 'merge'
    $script:gitAliasMap['gur'] = 'rebase'
    $script:gitAliasMap['gccd'] = 'clone'
    $script:gitAliasMap['gsw'] = 'switch'
    $script:gitAliasMap['gwt'] = 'worktree'
    $script:gitAliasMap['gwta'] = 'worktree add'
    $script:gitAliasMap['gwtl'] = 'worktree list'
    $script:gitAliasMap['gwtm'] = 'worktree move'
    $script:gitAliasMap['gwtr'] = 'worktree remove'
    $script:gitAliasMap['gwtp'] = 'worktree prune'

    if ($script:gitAliasMap.Count -eq 0) {
        Write-Warning "No git alias functions were found to register for completion."
        return
    }

    # 2. Create the proxy completer script block
    $proxyCompleter = {
        param($wordToComplete, $commandAst, $cursorPosition)

        $commandName = $commandAst.CommandElements[0].Value
        $subCommandLine = [string]$script:gitAliasMap[$commandName]
        $primarySubCommand = ($subCommandLine -split '\s+')[0]

        # Reconstruct the command line as if 'git <subcommand>' was typed
        $line = $commandAst.Extent.Text
        # CommandAst extent drops trailing whitespace, but completion context
        # depends on it (e.g. "gsw " vs "gsw"). Restore it using cursor offset.
        if ($cursorPosition -gt $line.Length) {
            $line += (' ' * ($cursorPosition - $line.Length))
        }
        $gitLine = $line -replace "^$commandName", "git $subCommandLine"
        $offset = ("git $subCommandLine").Length - $commandName.Length
        $gitCursorPosition = $cursorPosition + $offset
        if ($gitCursorPosition -lt 0) { $gitCursorPosition = 0 }
        if ($gitCursorPosition -gt $gitLine.Length) { $gitCursorPosition = $gitLine.Length }

        if ($primarySubCommand -eq 'worktree' -and $wordToComplete -notlike '-*') {
            $worktreeCompletions = Get-GitWorktreeCompletions `
                -CommandName $commandName `
                -Line $line `
                -WordToComplete $wordToComplete
            if ($worktreeCompletions -and $worktreeCompletions.Count -gt 0) {
                return $worktreeCompletions
            }
        }

        # Delegate to native completion for `git <subcommand> ...`.
        # This preserves completion for long options (e.g. --track, --detach)
        # and other git-specific argument completion behavior.
        try {
                $nativeCompletion = [System.Management.Automation.CommandCompletion]::CompleteInput(
                    $gitLine,
                    $gitCursorPosition,
                    $null
                )
                if ($null -ne $nativeCompletion -and
                    $null -ne $nativeCompletion.CompletionMatches -and
                    $nativeCompletion.CompletionMatches.Count -gt 0) {
                $delegateMatches = @($nativeCompletion.CompletionMatches)
                if ($primarySubCommand -in @('checkout', 'switch', 'merge', 'rebase', 'branch', 'reset', 'revert')) {
                    $delegateMatches = @($nativeCompletion.CompletionMatches | ForEach-Object {
                        if ($null -eq $_) { return }
                        $completionText = $_.CompletionText
                        if ($completionText -is [string] -and $completionText.StartsWith('#')) {
                            $safeText = Convert-ToPowerShellBranchCompletionText -BranchName $completionText
                            return [System.Management.Automation.CompletionResult]::new(
                                $safeText,
                                $_.ListItemText,
                                $_.ResultType,
                                $_.ToolTip
                            )
                        }

                        return $_
                    })
                }

                if ($primarySubCommand -eq 'worktree' -and $wordToComplete -notlike '-*') {
                    $worktreeCompletions = Get-GitWorktreeCompletions `
                        -CommandName $commandName `
                        -Line $line `
                        -WordToComplete $wordToComplete
                    if ($worktreeCompletions -and $worktreeCompletions.Count -gt 0) {
                        return $worktreeCompletions
                    }
                }

                if ($wordToComplete -like '-*') {
                    $optionCompletions = Get-GitLongOptionCompletions -SubCommandLine $subCommandLine -WordToComplete $wordToComplete
                    if ($optionCompletions -and $optionCompletions.Count -gt 0) {
                        $combined = @()
                        $seen = @{}
                        foreach ($item in @($delegateMatches + $optionCompletions)) {
                            if ($null -eq $item) { continue }
                            $key = $item.CompletionText
                            if (-not $seen.ContainsKey($key)) {
                                $combined += $item
                                $seen[$key] = $true
                            }
                        }

                        return $combined
                    }
                }

                return $delegateMatches
            }
        } catch {
            Write-Warning "Native completion delegation failed for alias '$commandName'."
        }

        # Long option fallback when native completion isn't available.
        $optionCompletions = Get-GitLongOptionCompletions -SubCommandLine $subCommandLine -WordToComplete $wordToComplete
        if ($optionCompletions -and $optionCompletions.Count -gt 0) {
            return $optionCompletions
        }

        if ($primarySubCommand -eq 'worktree' -and $wordToComplete -notlike '-*') {
            $worktreeCompletions = Get-GitWorktreeCompletions `
                -CommandName $commandName `
                -Line $line `
                -WordToComplete $wordToComplete
            if ($worktreeCompletions -and $worktreeCompletions.Count -gt 0) {
                return $worktreeCompletions
            }
        }

        # Final fallback when delegated completion is unavailable
        if ($primarySubCommand -in @('checkout', 'switch', 'merge', 'rebase', 'branch', 'reset', 'revert')) {
            try {
                $branches = git branch -a --format='%(refname:short)' |
                            ForEach-Object { $_ -replace '^remotes/origin/', '' } |
                            Sort-Object -Unique |
                            Where-Object { $_ -like "$wordToComplete*" }
                if ($branches) {
                    return $branches | ForEach-Object {
                        $branchName = $_
                        $safeText = Convert-ToPowerShellBranchCompletionText -BranchName $branchName
                        [System.Management.Automation.CompletionResult]::new($safeText, $branchName, 'ParameterValue', $branchName)
                    }
                }
            } catch {
                return @()
            }
        }

        # Return nothing if no completions are found
        return @()
    }

    # 3. Register the completer for every alias found
    foreach ($aliasName in $script:gitAliasMap.Keys) {
        # Ensure we only register for commands that actually exist
        if (Get-Command $aliasName -ErrorAction SilentlyContinue) {
            Register-ArgumentCompleter -CommandName $aliasName -ScriptBlock $proxyCompleter
        }
    }

    Write-Host "Git alias tab completion is now active for $($script:gitAliasMap.Count) aliases." -ForegroundColor Cyan
}

# --- Run Registration and Export Members ---

# This runs when the module is imported
Register-GitAliasCompletion

# Export all public functions and aliases for use in the shell
Export-ModuleMember -Function * -Alias *
