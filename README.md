# GitAliases.Extras

Custom PowerShell git aliases and tab completion helpers on top of `posh-git` and `git-aliases`.

## Install from PowerShell Gallery

```powershell
Install-Module GitAliases.Extras -Scope CurrentUser
Import-Module GitAliases.Extras
```

## Install from source

```powershell
git clone https://github.com/PhysShell/GitAliases.Extras.git "$HOME\Documents\PowerShell\Modules\GitAliases.Extras"
Import-Module GitAliases.Extras
```

## Prerequisites

- `git`
- `posh-git`
- `git-aliases`

Example bootstrap:

```powershell
Install-Module posh-git -Scope CurrentUser -Force
Install-Module git-aliases -Scope CurrentUser -Force
Install-Module GitAliases.Extras -Scope CurrentUser -Force
```

## Local quality checks

```powershell
.\tools\ci.ps1
```

## Publishing

This repository includes:

- `.github/workflows/ci.yml` for lint + tests
- `.github/workflows/publish.yml` for PSGallery publishing

To publish from CI:

1. Add repository secret `PSGALLERY_API_KEY`.
2. Bump `ModuleVersion` in `GitAliases.Extras.psd1`.
3. Push a tag `v<ModuleVersion>` (for example, `v0.1.0`) or run the publish workflow manually.

## License

WTFPL. See `LICENSE`.
