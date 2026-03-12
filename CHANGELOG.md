# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-03-12

### Removed
- `nvim`: removed `csv.vim` plugin (`chrisbra/csv.vim`) — no longer needed

## [1.0.1] - 2026-03-12

### Fixed
- `get.sh`: auto-install `git` and `curl` via `apt-get` when running as root on
  apt-based systems — bare `ubuntu:20.04` containers now need zero manual
  pre-installs (`_apt_bootstrap` helper runs `apt-get update` at most once)
- `get.sh`: sudo preflight check now correctly reports "running as root" instead
  of the misleading "apt package installs will be skipped" warning
- `modules/zsh.sh` `_set_default_shell`: `$USER` unbound variable crash in root
  containers replaced with `$(id -un)`
- `modules/zsh.sh` `_set_default_shell`: hardcoded `sudo usermod` replaced with
  `$SUDO usermod` — works on minimal images without `sudo` installed
- `modules/zsh.sh` `_set_default_shell`: `$SHELL` unbound variable crash guarded
  with `${SHELL:-}`
- `modules/zsh.sh` `_set_default_shell`: empty `zsh_path` guard prevents silent
  false-positive "already installed" and crashes on `usermod`

### Added
- `modules/zsh.sh`: `_patch_bashrc_for_docker` — when `/.dockerenv` is detected,
  appends `exec zsh` guard to `~/.bashrc` so `docker exec -it … bash` sessions
  auto-switch to zsh; fires for all profiles including `docker`
- `install.sh`: warns when `workstation` profile is selected inside a Docker
  container, suggesting the lighter `docker` profile
- `get.sh`: Docker usage documented in header — Option A (combined one-liner) and
  Option B (`docker cp` for zero in-container pre-reqs)

## [1.0.0] - 2026-03-11

Complete overhaul of the dotfiles infrastructure: modular profiles, Neovim, CI, and bootstrap.

### Added
- `get.sh` — one-line bootstrap to install any profile on a fresh machine
- Neovim config with full modern plugin stack: LSP (mason), blink.cmp, Treesitter, Telescope,
  conform.nvim (format-on-save), gitsigns, which-key, flash.nvim, trouble, and 20+ colorschemes
- Profile system: separate `workstation` / `server` configs
- CI pipeline with Docker-based test matrix and Bash test suite
- `tmux plugin update` step in `update.sh`
- `zoxide` shell integration
- `delta` as git pager (replaces `diff-so-fancy`)
- `ruff` formatter (replaces `black` + `isort`)

### Changed
- `install.sh` rewritten: pre-checks, modular structure, profile-aware package selection
- `update.sh` rewritten: modular, idempotent steps (zsh, tmux, nvim, git tools)
- `gitconfig` uses `[includeIf]` local-override pattern
- Symlink setup extracted into a dedicated helper
- Zsh `fzf-tab` preview uses `eza` instead of `ls`
- Tmux plugin install automated — no longer requires manual `<prefix>+I`

### Removed
- Vim (`vim/`) config replaced by Neovim
- Personal utility scripts
- `_download_bin` unused helper

### Fixed
- Tmux plugins restricted to workstation profile only
- Zsh history setopts and `share_history` placement
- `local` keyword outside function causing shell crash
- `--ff-only` handling for rebased tmux plugins
- `get.sh`: non-git destination guard, soft-fail on pull errors

## [0.3.0] - 2022-03-07

### Changed
- Tmux, Vim, Zsh, and Git config updates

## [0.2.0] - 2020-11-20

### Added
- Git and CMake source-build install scripts
- ShellCheck, shfmt, cheat packages
- Ranger config files, `colored-man-pages` zsh plugin
- Nerd Font patching instructions

### Changed
- Vim plugin manager migrated from Vundle to vim-plug
- Sudo requirements relaxed for CMake and Git installs

## [0.1.0] - 2020-07-03

### Added
- Initial dotfiles: Zsh (oh-my-zsh + fzf), Tmux, Vim, and monolithic `install.sh`

[Unreleased]: https://github.com/tpedzimaz/dotfiles/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/tpedzimaz/dotfiles/compare/v0.3.0...v1.0.0
[0.3.0]: https://github.com/tpedzimaz/dotfiles/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/tpedzimaz/dotfiles/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/tpedzimaz/dotfiles/releases/tag/v0.1.0
