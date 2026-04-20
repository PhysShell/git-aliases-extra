# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and the project uses Semantic Versioning.

## [0.1.7] - 2026-04-20

### Added

- Enhanced not-merged branch inspection:
  - `Get-BranchesNotMergedToDevelopDetails` with author, unique-commit count, insertion/deletion stats, changed-file count, and truncated changed-file preview.
  - `gbnmdi` interactive browser (arrow-key navigation + Enter selection) with detail views:
    - `Commits` (default)
    - `Changes` (diff stat + name-status)
    - `Patch` (full patch output)
- Extended `gbnmd` and `gbnmdr` with:
  - `-Detailed`
  - `-Interactive`
  - `-View Commits|Changes|Patch`
  - optional date filters: `-Since`, `-LastDays`
- Integration test coverage for detailed not-merged branch output and branch-stability checks (current branch remains unchanged).

### Changed

- Not-merged branch data collection now keeps stable ref metadata (`Ref`, `BaseRef`) to support richer visual inspection without branch switching.
- README expanded with interactive usage and enriched table examples for `gbnmd`/`gbnmdr`/`gbnmdi`.

### Fixed

- Windows PowerShell 5.1 import compatibility for BOM-less module sources:
  - mojibake detection now uses ASCII-only Unicode escape sequences in regex literals;
  - the module source remains ASCII-only to avoid ANSI parsing regressions.
- `PSScriptAnalyzer` warning cleanup for `Convert-FromGitMojibake` by replacing an empty catch block with verbose diagnostic output.

## [0.1.6] - 2026-03-13

### Added

- Branch visibility helpers:
  - `Get-BranchesNotMergedToDevelop` with `-Since`, `-LastDays`, `-BaseBranch`, and `-RemoteOnly` parameters.
  - compatibility wrapper `Get-BranchesNotMergedToDevelopSinceDate`.
  - shortcut alias `gbnms` for `Get-BranchesNotMergedToDevelop`.
- New branch aliases:
  - `gbnmd` -> `git branch --no-merged <base> --sort=-committerdate` (default base: `develop`)
  - `gbnmdr` -> same command with `-r`
  - `gbsc` -> `git branch --show-current`
- Integration tests for:
  - `gbsc` current-branch output;
  - `gbnmd`/`gbnmdr` filtering and ordering;
  - date-based filtering (`Since`/`LastDays`) and remote-only behavior for `Get-BranchesNotMergedToDevelop`.

### Changed

- README documentation expanded with a dedicated section for not-merged branch helpers and usage examples.

## [0.1.5] - 2026-03-04

### Changed

- Branch completion now supports both match strategies:
  - priority 1: branch names that start with the typed fragment (`StartsWith`);
  - priority 2: branch names that contain the typed fragment anywhere (`Contains`).
- `gsw` and other branch-oriented alias completions now use the same prioritized branch selection, including native-completion delegation paths.

### Added

- Integration test coverage for branch completion ordering to verify that `StartsWith` results are listed before `Contains` results.

## [0.1.4] - 2026-02-20

### Fixed

- Publish pipeline packaging layout for PSGallery:
  - `tools/prepare-publish.ps1` now stages files under `<output>\git-aliases-extra\...`
  - script returns the module directory path (not the staging root), matching `Publish-Module -Path` expectations.
- Module test coverage for publish staging updated to validate module-directory output shape.

## [0.1.3] - 2026-02-20

### Added

- Smart `gwta` auto-path mode for omitted path:
  - `gwta <branch-or-start-point>`
  - `gwta -b <new-branch>`
- Branch completion for worktree-add flows:
  - `gwta -b <TAB>`
  - `gwta <path> <TAB>`
  - `gwta <path> -f <TAB>`
  - `gwt add <path> <TAB>`
  - `gwt add <path> -f <TAB>`
- Integration tests for `gwta` auto-path and branch completion, including `-f` scenarios.

### Changed

- README updated with dedicated `gwta` usage docs and examples.

## [0.1.2] - 2026-02-19

### Added

- Local multi-shell test execution (`powershell` + `pwsh`) in `tools/test.ps1` with clear missing-shell errors.

### Fixed

- Stabilized long-option completion integration tests in Windows PowerShell 5.1 (`gsw`/`gco`).


## [0.1.1] - 2026-02-19

### Added

- Publish staging script `tools/prepare-publish.ps1` to package runtime files only.
- Automated release-notes extraction from `CHANGELOG.md` via `tools/get-release-notes.ps1`.
- Additional module tests for publish layout and manifest dependency metadata.

### Changed

- Pinned `RequiredModules` to explicit versions:
  - `posh-git` `1.1.0`
  - `git-aliases` `0.3.8`
- Updated publish workflow to:
  - run lint + tests before publish;
  - inject release notes from changelog;
  - publish from staged runtime-only layout.

### Fixed

- Removed `ExternalModuleDependencies` to avoid dependency-skip warnings during publish.
- Reduced NuGet packaging noise by excluding repo-only content (`tests`, CI files, helper scripts) from publish artifact.

## [0.1.0] - 2026-02-19

### Added

- Standalone `git-aliases-extra` module extracted from dotfiles.
- Extended git alias completion for custom aliases and long options.
- `gsw` fallback logic for remote-only branch switching edge cases.
- `gfp` helper for `git format-patch --cover-letter --stat --stdout`.
- Worktree aliases with completion support for worktree paths.
- Lint, test, CI workflows, and local hook installation scripts.

### Changed

- Renamed module from `GitAliases.Extras` to `git-aliases-extra`.
