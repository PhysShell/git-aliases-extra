# GitAliases.Extras

Custom PowerShell git aliases and tab completion helpers on top of `posh-git` and `git-aliases`.

## Module installation

Install from PowerShell Gallery:

```powershell
Install-Module GitAliases.Extras -Scope CurrentUser
Import-Module GitAliases.Extras
```

Install from source:

```powershell
git clone https://github.com/PhysShell/GitAliases.Extras.git "$HOME\Documents\PowerShell\Modules\GitAliases.Extras"
Import-Module GitAliases.Extras
```

Install dependencies:

```powershell
Install-Module posh-git -Scope CurrentUser -Force
Install-Module git-aliases -Scope CurrentUser -Force
Install-Module GitAliases.Extras -Scope CurrentUser -Force
```

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
2. Bump `ModuleVersion` in `GitAliases.Extras.psd1`.
3. Push a tag `v<ModuleVersion>` (for example, `v0.1.0`) or run the publish workflow manually.

## What CI checks

- `PSScriptAnalyzer` linting with `PSScriptAnalyzerSettings.psd1`
- `Pester` tests in `tests\`
- GitHub Actions matrix on:
  - Windows PowerShell
  - PowerShell 7

## License

WTFPL. See `LICENSE`.
