# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and the project uses Semantic Versioning.

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
