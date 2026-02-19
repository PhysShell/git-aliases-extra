# git-aliases-extra

Custom PowerShell git aliases and tab completion helpers on top of `posh-git` and `git-aliases` with full tab completion support for aliased commands.

Mainly inspired by https://github.com/zh30/zsh-shortcut-git.

Example of how I set git-aliases-extra up in dotfiles for Windows can be found at https://github.com/PhysShell/dotfiles.

## Breaking Changes (2026-02-19)

- Renamed module: `GitAliases.Extras` -> `git-aliases-extra`
- Renamed manifest/script files:
  - `GitAliases.Extras.psd1` -> `git-aliases-extra.psd1`
  - `GitAliases.Extras.psm1` -> `git-aliases-extra.psm1`
- Renamed repository URL:
  - `https://github.com/PhysShell/GitAliases.Extras` -> `https://github.com/PhysShell/git-aliases-extra`

Migration steps:

```powershell
Remove-Module GitAliases.Extras -ErrorAction SilentlyContinue
Import-Module git-aliases-extra
```

## Module installation

Install from PowerShell Gallery:

```powershell
Install-Module git-aliases-extra -Scope CurrentUser
Import-Module git-aliases-extra
```

Install from source:

```powershell
git clone https://github.com/PhysShell/git-aliases-extra.git "$HOME\Documents\PowerShell\Modules\git-aliases-extra"
Import-Module git-aliases-extra
```

Install dependencies:

```powershell
Install-Module posh-git -Scope CurrentUser -Force
Install-Module git-aliases -Scope CurrentUser -Force
Install-Module git-aliases-extra -Scope CurrentUser -Force
```

## Alias discovery

Use `Get-Git-Aliases` to inspect available aliases and their definitions.

List all aliases:

```powershell
Get-Git-Aliases
```

Show one alias:

```powershell
Get-Git-Aliases grsh
```

List only aliases from `git-aliases`:

```powershell
Get-Git-Aliases -Base
```

List only aliases from `git-aliases-extra`:

```powershell
Get-Git-Aliases -Extras
```

`Get-Git-Aliases` includes aliases from both:
- `git-aliases`
- `git-aliases-extra`

Default output order:
- `extras` group first
- `base` group second
- alphabetical order inside each group

## Aliases

| Alias | Command | Source |
| :---- | :------ | :----- |
| gapt | git apply --3way @args | extra |
| gccd | param([Parameter(ValueFromRemainingArguments=$true)][string[]]$rest) <br> git clone --recurse-submodules @rest <br> $last = if ($rest.Count) { $rest[-1] } else { '' } <br> if ($last -match '\.git$') { $last = $last -replace '\.git$','' } <br> if ($last) { <br>   $dirName = Split-Path $last -Leaf <br>   if (Test-Path $dirName) { <br>     Set-Location $dirName <br>   } <br> } | extra |
| gcor | git checkout --recurse-submodules @args | extra |
| gdct | git describe --tags (git rev-list --tags --max-count=1) | extra |
| gdnolock | git diff @args ":(exclude)package-lock.json" ":(exclude)*.lock" | extra |
| gdt | git diff-tree --no-commit-id --name-only -r @args | extra |
| gdv | git diff -w @args \| Out-String \| less | extra |
| gfo | git fetch origin @args | extra |
| gfp | Create `format-patch` mbox (`--cover-letter --stat --stdout`) from `<remote>/<target>..HEAD`. [source](./git-aliases-extra.psm1#L519) | extra |
| ghash | Return commit hash for HEAD or HEAD~N (`-Short` supported). [source](./git-aliases-extra.psm1#L486) | extra |
| glp | param([string]$format) if($format){ git log --pretty=$format } else { git log } | extra |
| gmtl | git mergetool --no-prompt @args | extra |
| gmtlvim | git mergetool --no-prompt --tool=vimdiff @args | extra |
| grl | git reflog @args | extra |
| grsh | git reset --soft HEAD~1 | extra |
| gsw | Switch to local branch or create tracking branch for remote-only target. [source](./git-aliases-extra.psm1#L594) | extra |
| gswc | git switch -c @args | extra |
| gtl | param($p='') git tag --sort=-v:refname -n -l "$p*" | extra |
| gtv | git tag \| Sort-Object { $_ -as [version] } | extra |
| gunwip | if (git log -n 1 \| Select-String -Quiet -- "--wip--") { git reset HEAD~1 } | extra |
| gwip | git add -A; git rm (git ls-files --deleted) 2>$null; git commit --no-verify --no-gpg-sign -m "--wip-- [skip ci]" | extra |
| gwt | git worktree @args | extra |
| gwta | git worktree add @args | extra |
| gwtl | git worktree list @args | extra |
| gwtm | git worktree move @args | extra |
| gwtp | git worktree prune @args | extra |
| gwtr | git worktree remove @args | extra |
| ga | git add $args | base |
| gaa | git add --all $args | base |
| gapa | git add --patch $args | base |
| gau | git add --update $args | base |
| gb | git branch $args | base |
| gba | git branch -a $args | base |
| gbd | git branch -d $args | base |
| gbda | $MainBranch = Get-Git-MainBranch <br> $MergedBranchs = $(git branch --merged \| Select-String "^(\*\|\s*($MainBranch\|develop\|dev)\s*$)" -NotMatch).Line <br> $MergedBranchs \| ForEach-Object { <br> 	if ([string]::IsNullOrEmpty($_)) { <br> 		return <br> 	} <br> 	git branch -d $_.Trim() <br> } | base |
| gbl | git blame -b -w $args | base |
| gbnm | git branch --no-merged $args | base |
| gbr | git branch --remote $args | base |
| gbs | git bisect $args | base |
| gbsb | git bisect bad $args | base |
| gbsg | git bisect good $args | base |
| gbsr | git bisect reset $args | base |
| gbss | git bisect start $args | base |
| gc | git commit -v $args | base |
| gc! | git commit -v --amend $args | base |
| gca | git commit -v -a $args | base |
| gca! | git commit -v -a --amend $args | base |
| gcam | git commit -a -m $args | base |
| gcan! | git commit -v -a --no-edit --amend $args | base |
| gcans! | git commit -v -a -s --no-edit --amend $args | base |
| gcb | git checkout -b $args | base |
| gcd | git checkout develop $args | base |
| gcf | git config --list $args | base |
| gcl | git clone --recursive $args | base |
| gclean | git clean -df $args | base |
| gcm | $MainBranch = Get-Git-MainBranch <br>  <br> git checkout $MainBranch $args | base |
| gcmsg | git commit -m $args | base |
| gcn! | git commit -v --no-edit --amend $args | base |
| gco | git checkout $args | base |
| gcount | git shortlog -sn $args | base |
| gcp | git cherry-pick $args | base |
| gcpa | git cherry-pick --abort $args | base |
| gcpc | git cherry-pick --continue $args | base |
| gcs | git commit -S $args | base |
| gd | git diff $args | base |
| gdca | git diff --cached $args | base |
| gds | git diff --staged $args | base |
| gdw | git diff --word-diff $args | base |
| gf | git fetch $args | base |
| gfa | git fetch --all --prune $args | base |
| gg | git gui citool $args | base |
| gga | git gui citool --amend $args | base |
| ggf | $CurrentBranch = Get-Git-CurrentBranch <br>  <br> git push --force origin $CurrentBranch | base |
| ggfl | $CurrentBranch = Get-Git-CurrentBranch <br>  <br> git push --force-with-lease origin $CurrentBranch | base |
| ggl | $CurrentBranch = Get-Git-CurrentBranch <br>  <br> git pull origin $CurrentBranch | base |
| ggp | $CurrentBranch = Get-Git-CurrentBranch <br>  <br> git push origin $CurrentBranch | base |
| ggpnp | ggl; ggp $args | base |
| ggsup | $CurrentBranch = Get-Git-CurrentBranch <br>  <br> git branch --set-upstream-to=origin/$CurrentBranch | base |
| ghh | git help $args | base |
| gignore | git update-index --assume-unchanged $args | base |
| gignored | git ls-files -v \| Select-String "^[a-z]" -CaseSensitive | base |
| gl | git pull $args | base |
| glg | git log --stat --color $args | base |
| glgg | git log --graph --color $args | base |
| glgga | git log --graph --decorate --all $args | base |
| glgm | git log --graph --max-count=10 $args | base |
| glgp | git log --stat --color -p $args | base |
| glo | git log --oneline --decorate --color $args | base |
| glog | git log --oneline --decorate --color --graph $args | base |
| gloga | git log --oneline --decorate --color --graph --all $args | base |
| glol | git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit $args | base |
| glola | git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit --all $args | base |
| glum | $MainBranch = Get-Git-MainBranch <br>  <br> git pull upstream $MainBranch $args | base |
| gm | git merge $args | base |
| gmom | $MainBranch = Get-Git-MainBranch <br>  <br> git merge origin/$MainBranch $args | base |
| gmt | git mergetool --no-prompt $args | base |
| gmtvim | git mergetool --no-prompt --tool=vimdiff $args | base |
| gmum | $MainBranch = Get-Git-MainBranch <br>  <br> git merge upstream/$MainBranch $args | base |
| gp | git push $args | base |
| gpd | git push --dry-run $args | base |
| gpf | git push --force-with-lease $args | base |
| gpf! | git push --force $args | base |
| gpoat | git push origin --all <br> git push origin --tags | base |
| gpr | git pull --rebase $args | base |
| gpra | git pull --rebase --autostash $args | base |
| gpristine | git reset --hard <br> git clean -dfx | base |
| gprom | $MainBranch = Get-Git-MainBranch <br>  <br> git pull --rebase origin $MainBranch $args | base |
| gprv | git pull --rebase -v $args | base |
| gpsup | $CurrentBranch = Get-Git-CurrentBranch <br>  <br> git push --set-upstream origin $CurrentBranch | base |
| gpu | git push upstream $args | base |
| gpv | git push -v $args | base |
| gr | git remote $args | base |
| gra | git remote add $args | base |
| grb | git rebase $args | base |
| grba | git rebase --abort $args | base |
| grbc | git rebase --continue $args | base |
| grbi | git rebase -i $args | base |
| grbm | $MainBranch = Get-Git-MainBranch <br>  <br> git rebase $MainBranch $args | base |
| grbs | git rebase --skip $args | base |
| grh | git reset $args | base |
| grhh | git reset --hard $args | base |
| grmv | git remote rename $args | base |
| groh | $CurrentBranch = Get-Git-CurrentBranch <br>  <br> git reset origin/$CurrentBranch --hard | base |
| grrm | git remote remove $args | base |
| grs | git restore $args | base |
| grset | git remote set-url $args | base |
| grst | git restore --staged $args | base |
| grt | try { <br> 	$RootPath = git rev-parse --show-toplevel <br> } <br> catch { <br> 	$RootPath = "." <br> } <br> Set-Location $RootPath | base |
| gru | git reset -- $args | base |
| grup | git remote update $args | base |
| grv | git remote -v $args | base |
| gsb | git status -sb $args | base |
| gsd | git svn dcommit $args | base |
| gsh | git show $args | base |
| gsi | git submodule init $args | base |
| gsps | git show --pretty=short --show-signature $args | base |
| gsr | git svn rebase $args | base |
| gss | git status -s $args | base |
| gst | git status $args | base |
| gsta | git stash save $args | base |
| gstaa | git stash apply $args | base |
| gstc | git stash clear $args | base |
| gstd | git stash drop $args | base |
| gstl | git stash list $args | base |
| gstp | git stash pop $args | base |
| gsts | git stash show --text $args | base |
| gsu | git submodule update $args | base |
| gts | git tag -s $args | base |
| gunignore | git update-index --no-assume-unchanged $args | base |
| gup | Write-Host-Deprecated "gup" "gpr" <br> git pull --rebase $args | base |
| gupa | Write-Host-Deprecated "gupa" "gpra" <br> git pull --rebase --autostash $args | base |
| gupv | Write-Host-Deprecated "gupv" "gprv" <br> git pull --rebase -v $args | base |
| gvt | git verify-tag $args | base |
| gwch | git whatchanged -p --abbrev-commit --pretty=medium $args | base |
## Quality checks

Run both lint and tests:

```powershell
.\tools\ci.ps1
```

Run only lint:

```powershell
.\tools\ci.ps1 -LintOnly
```

Run only tests:

```powershell
.\tools\ci.ps1 -TestOnly
```

## Commit hooks

Install local git hooks:

```powershell
.\tools\install-hooks.ps1
```

Installed hooks:
- `pre-commit` (lightweight no-op)
- `commit-msg` (runs `tools/ci.ps1`)

Checks are skipped when:
- commit message contains `[skip precommit hook]` or `[skip pch]`
- there are no working tree changes (for example, `git commit --allow-empty ...`)

## Publishing

This repository includes:

- `.github/workflows/ci.yml` for lint + tests
- `.github/workflows/publish.yml` for PSGallery publishing

To publish from CI:

1. Add repository secret `PSGALLERY_API_KEY`.
2. Bump `ModuleVersion` in `git-aliases-extra.psd1`.
3. Push a tag `v<ModuleVersion>` (for example, `v0.1.0`) or run the publish workflow manually.

## What CI checks

- `PSScriptAnalyzer` linting with `PSScriptAnalyzerSettings.psd1`
- `Pester` tests in `tests\` (module + integration)
- GitHub Actions matrix on:
  - Windows PowerShell
  - PowerShell 7

## License

WTFPL. See `LICENSE`.