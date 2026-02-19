# Changelog

All notable changes to this project are documented in this file.

The format is based on Keep a Changelog and the project uses Semantic Versioning.

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
