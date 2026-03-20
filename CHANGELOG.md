# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.3] - 2026-03-20

### Fixed
- `nvim/init.lua`: blink.cmp path completions truncated long names — default
  `label.width.max=60` and `label_description.width.max=30` were the culprits;
  raised to 80/50 respectively and bumped `min_width` from 15 to 30

## [1.2.2] - 2026-03-20

### Fixed
- `modules/base.sh`: delta `.deb` install was constructing the asset filename
  (`git-delta_VERSION_amd64.deb`) but delta 0.19.0 renamed the asset to
  `git-delta-musl_VERSION_amd64.deb`, silently breaking installation on Ubuntu
  20.04/22.04; fixed by using `_gh_release_info` to look up the exact URL from
  the GitHub API instead of hardcoding the filename pattern

## [1.2.1] - 2026-03-20

### Changed
- `README.md` + `install.sh`: font install section now offers three explicit
  options — `p10k configure` (wizard, easiest), `~/.dotfiles/scripts/install-fonts.sh`
  (absolute path, works after `curl | bash` install), and a `bash <(curl ...)` one-liner
  (no local repo required); fixes confusing `./scripts/install-fonts.sh` relative path
  shown in post-install message when user is not in the dotfiles directory

## [1.2.0] - 2026-03-20

### Added
- `lib/utils.sh`: `_ver_older_than` — version comparison helper using `sort -V`
  (GNU coreutils); returns true when `$1 < $2`, false when either arg is empty
- `modules/neovim.sh`: `_nvim_warn_shadows` — detects pre-existing `nvim` copies
  at `~/.local/bin/nvim` or `~/bin/nvim` that shadow the managed install at
  `/usr/local/bin/nvim`; runs at both install time and on the skip-already-current
  path so a shadow is never silently missed
- `update.sh`: `_check_path_shadows` — PATH shadow check that always runs at the
  end of `update.sh` (read-only, no side effects); walks PATH dirs before
  `/usr/local/bin`, reports older/duplicate/newer shadows for each managed tool
  (`nvim`, `xcape`); skipped with an informational message if `/usr/local/bin` is
  not in PATH at all

### Fixed
- `modules/base.sh`: add `locales` package and `locale-gen en_US.UTF-8` to
  `install_base` — on fresh minimal Ubuntu images the locale data is absent,
  causing Perl to warn on every `Ctrl+R` invocation (fzf's history widget invokes
  `perl` for multi-line deduplication); idempotent (`locale -a` check guards re-run)
- `install.sh` + `modules/zsh.sh`: post-install message now correctly reflects
  whether the default shell change succeeded or failed; uses `_SHELL_IS_ZSH` flag
  set by `_set_default_shell`; clarifies that `exec zsh` activates the shell
  immediately without a re-login

## [1.1.3] - 2026-03-18

### Fixed
- `zsh/.zshrc`: set `fzf-tab` popup minimum size (60 columns × 8 rows) so file/folder names are not truncated in the completion popup

### Removed
- `tmux/.tmux.conf.local`: removed `tmux-resurrect` and `tmux-continuum` plugins — `@continuum-restore 'on'` was automatically restoring all saved sessions on every tmux launch, causing ~20 unwanted windows/panes to appear on startup

## [1.1.2] - 2026-03-17

### Changed
- `README.md`: added Table of Contents

## [1.1.1] - 2026-03-17

### Fixed
- `x11/.xprofile` + `scripts/install-x11.sh`: replaced `setxkbmap
  caps:ctrl_modifier` with `xmodmap`-based approach using `Hyper_L` as a
  unique keysym for Caps Lock; physical Ctrl key (`Control_L`) is no longer
  affected by xcape, so tapping the real Ctrl key no longer sends Escape
- GNOME: `gnome-settings-daemon` resets xkb after `.xprofile` runs, leaving
  the remapping silently inactive; fixed by adding
  `x11/.config/autostart/caps-remap.desktop` which re-applies the mapping
  after the session is fully ready (installed to
  `~/.config/autostart/caps-remap.desktop` by `install-x11.sh`)
- `scripts/install-x11.sh`: xmodmap `add Control = Hyper_L` could fail with
  `BadValue` and abort the script under `set -euo pipefail` before xcape was
  started; moved remapping logic to `x11/caps-remap.sh` with `|| true` guards

### Added
- `x11/caps-remap.sh`: dedicated remapping script — single source of truth for
  the xmodmap + xcape commands; documents mechanism, limitations (Wayland,
  startx, keycode assumption, Hyper_L mod4 side-effect, `-t 200` threshold)
- `x11/.config/autostart/caps-remap.desktop`: GNOME autostart entry (see above)

### Changed
- `x11/.xprofile`: delegates to `~/.local/bin/caps-remap`; documents GNOME
  override caveat, Wayland limitation, and startx/xinit gap at the top of file
- `scripts/install-x11.sh`: symlinks `caps-remap.sh` to
  `~/.local/bin/caps-remap` and the autostart `.desktop` file; stale
  `setxkbmap` references removed from comments and log messages
- `README.md`: x11 directory tree and symlink map updated with new files;
  X11 section corrected (xmodmap replaces setxkbmap; GNOME, Wayland, and
  startx caveats added)

## [1.1.0] - 2026-03-16

### Added
- `scripts/install-fonts.sh`: downloads and installs MesloLGS NF (4 variants)
  to `~/.local/share/fonts/` — no sudo required; validates downloads and
  refreshes fontconfig cache
- `scripts/install-x11.sh`: installs `xcape` from source (alols/xcape) and
  symlinks `x11/.xprofile`; applies remapping immediately and persists via
  `~/.xprofile` at next X session login
- `x11/.xprofile`: Caps Lock dual-function remapping — Ctrl when held, Escape
  when tapped alone (uses `setxkbmap` + `xcape`)
- `update.sh`: added `xcape` to known tools; rebuilds from source via
  `alols/xcape` with `--check` support and sudo guard

### Changed
- `install.sh`: post-install hints now include font and X11 remapping steps for
  `workstation` profile; docker profile notes these as local-machine-only steps
- `README.md`: added Font section (MesloLGS NF — required for icons; per-
  terminal setup instructions for GNOME Terminal, Konsole, Terminator,
  Alacritty, kitty, urxvt, VS Code); added `x11/.xprofile` to directory
  structure and symlink table; replaced demo SVG with MP4 video

## [1.0.4] - 2026-03-13

### Fixed
- `lib/utils.sh` `detect_sudo()`: rewritten as a pure probe — no output, no
  `sudo -v` interactive call; eliminates duplicate warnings and unexpected
  password prompts at startup
- `lib/utils.sh` `run_checks()`: replaced single hardcoded message with 4-state
  `$SUDO_STATUS` switch (`root` / `sudo_passwordless` / `sudo_password` /
  `nosudo`); `sudo_password` case demoted from `log_ok` (✓) to `log_info` since
  credentials are not yet validated
- `modules/neovim.sh`: `sudo -v` credential refresh moved to after the GitHub
  tarball download (inside `if $CAN_SUDO`), preventing 15-minute cache expiry
  during slow downloads
- `modules/neovim.sh` / `modules/zsh.sh`: added `sudo -n true` pre-check before
  each late-phase `sudo -v` call; emits `log_warn` if cache may have expired so
  the user is not surprised by a prompt
- `get.sh`: cosmetic sudo preflight check now respects `NOSUDO=1` — no longer
  reports "✓ sudo" when sudo is explicitly disabled

### Added
- `NOSUDO=1` env var support across all entry points: forces user-local
  (`~/.local/bin`) install path and skips all apt/sudo operations even when
  `sudo` is technically available; documented in `install.sh`, `update.sh`, and
  `get.sh` usage headers
- `lib/utils.sh` `run_checks()`: profile-aware sudo footprint note — lists
  exactly which operations will use `sudo` for the active `$PROFILE`
- Per-tool pre-install disclosure in all installer modules: each tool now logs
  its target version and destination path before downloading (unified pattern
  across `modules/base.sh`, `modules/neovim.sh`, `modules/tools.sh`,
  `modules/zsh.sh`, `modules/tmux.sh`)
- `modules/base.sh`: DRY `_pkgs` arrays — single declaration drives both
  `log_info` disclosure and `apt_install` call, eliminating list duplication

### Changed
- `update.sh`: bare `detect_sudo` call replaced with explicit `log_info` +
  4-state `$SUDO_STATUS` messaging giving accurate context for the update path
- `modules/tools.sh` `_install_ruff`: disclosure now uses `uv tool bin-dir`
  (PATH shim location) instead of `uv tool dir` (venv location)

## [1.0.3] - 2026-03-13

### Added
- **No-sudo support**: when `sudo` is unavailable, `modules/base.sh` now fetches
  prebuilt binaries (`rg`, `fd`, `jq`, `delta`, `eza`, `fzf`, `zoxide`) from
  GitHub releases into `~/.local/bin` instead of aborting
- `_install_ripgrep`, `_install_fd`, `_install_jq` — dedicated helpers for
  no-sudo binary installs (musl tarball or single-binary releases)
- `_install_delta` / `_install_eza` — extended with no-sudo tarball path alongside
  existing `.deb` / PPA paths
- `modules/zsh.sh`: guard that skips oh-my-zsh, plugins, and zshrc setup when
  `zsh` is not available; prints actionable reinstall hint
- `test.sh`: `nosudo` profile — verifies all `~/.local/bin` binaries are present
  and functional; confirms `sudo` is absent in the test environment
- `test-local.sh`: `--profile nosudo` flag and `--skip-nosudo` flag; `run_nosudo`
  runner builds via `Dockerfile.nosudo` and runs the nosudo test suite
- `.github/workflows/install.yml`: `install-nosudo` job — matrix across Ubuntu
  20.04 / 22.04 / 24.04 as a non-root user with no `sudo`

### Changed
- `modules/base.sh`: `install_base` restructured — apt path and no-sudo path are
  symmetric branches; prints PATH hint when binaries land in `~/.local/bin`
- `modules/base.sh` `_install_zoxide` / `_install_delta` / `_install_eza`: apt /
  `.deb` fallbacks now guarded with `$CAN_SUDO` to avoid false errors
- `lib/utils.sh`: no-sudo warning message updated to mention `~/.local/bin`

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

[Unreleased]: https://github.com/YASoftwareDev/dotfiles/compare/v1.1.3...HEAD
[1.1.3]: https://github.com/YASoftwareDev/dotfiles/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/YASoftwareDev/dotfiles/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/YASoftwareDev/dotfiles/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/YASoftwareDev/dotfiles/compare/v1.0.4...v1.1.0
[1.0.4]: https://github.com/YASoftwareDev/dotfiles/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/YASoftwareDev/dotfiles/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/YASoftwareDev/dotfiles/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/YASoftwareDev/dotfiles/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/YASoftwareDev/dotfiles/compare/v0.3.0...v1.0.0
[0.3.0]: https://github.com/YASoftwareDev/dotfiles/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/YASoftwareDev/dotfiles/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/YASoftwareDev/dotfiles/releases/tag/v0.1.0
