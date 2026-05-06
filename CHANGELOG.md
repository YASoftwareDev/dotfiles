# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.6.6] - 2026-05-06

### Fixed
- `update.sh`: `_do_update_neovim()` now checks glibc version before downloading
  the latest Neovim binary. On systems with glibc < 2.32 (Ubuntu 20.04 and older)
  it pins to the legacy v0.9.5 binary and skips the update, preventing the update
  path from silently replacing a working legacy install with an incompatible binary.
  Also removes any broken `~/.local/bin/nvim` shadow binary that would mask a
  working `/usr/local/bin/nvim` on the same system.

## [1.6.5] - 2026-05-06

### Fixed
- `README.md`: Update section now documents `NOSUDO=1 ./update.sh` for skipping
  apt and updating only user-local binaries in `~/.local/bin`.

## [1.6.4] - 2026-05-06

### Added
- Machine-local override files for all major tools, with example templates:
  - `~/.zshrc.local` - already sourced by `.zshrc`; added `zsh/.zshrc.local.example`
  - `~/.tmux.conf.server` - already sourced by `.tmux.conf.local`; added `tmux/.tmux.conf.server.example`
  - `~/.config/nvim/local.lua` - new: sourced at end of `init.lua` via `dofile` if readable; added `nvim/.config/nvim/local.lua.example`
- `README.md`: Machine-specific config section now lists all four override files in a table with example template paths.

## [1.6.3] - 2026-05-06

### Fixed
- `README.md`: Update section now shows the correct two-step flow - `git pull`
  first (to get config file changes), then `./update.sh` (to upgrade tool binaries
  and plugins). The previous single-command version was misleading: `update.sh`
  does not pull the dotfiles repo and does not install tools added in newer
  versions. Also documents `get.sh` as the simpler alternative and `--check` mode.
- `README.md`: Machine-specific config section now lists `~/.gitconfig.local`
  alongside `~/.zshrc.local` and `~/.p10k.zsh`, with a pointer to
  `git/.gitconfig.local.example`.

## [1.6.2] - 2026-05-06

### Fixed
- `git/.gitconfig`: removed private `[user]`, `[credential *]`, and `[url *]`
  sections that were committed to the public repo. These belong in
  `~/.gitconfig.local`, which is already included at the end of `.gitconfig`
  and is never tracked by git. Also moved `[pull]`, `[rebase]`, `[fetch]`,
  and `[diff]` tool settings above the `[include]` line so local settings can
  override them.

### Added
- `git/.gitconfig.local.example`: template showing the structure for
  `~/.gitconfig.local` (user identity, credential helpers, URL rewrites).

## [1.6.1] - 2026-05-06

### Fixed
- `install.sh`: the "Activate zsh for this session: exec zsh" advisory was shown
  even when the installer ran non-interactively (e.g. `curl ... | bash`). In that
  context the bash process is ephemeral - the user's real terminal session was
  already in zsh. A new `NXS_STDIN_IS_TTY` flag (`[ -t 0 ]`) gates the exec-zsh
  advice so it only appears in live interactive sessions.

## [1.6.0] - 2026-05-06

### Added
- `install.sh`: post-install "Next steps" summary is now context-aware. A new
  `_compute_next_steps_state()` function reads actual system state after every
  install - login shell (from `/etc/passwd` by UID, not the stale `$SHELL` env
  var), current process type (`ZSH_VERSION`), p10k config presence, SSH session
  detection, font installation state (four values: `installed`, `cache_stale`,
  `missing`, `unknown_remote`), and local X11 session vs SSH X-forwarding.
  Only steps that genuinely require action are shown; steps already complete are
  suppressed. When running over SSH the font advisory is shown as a lightweight
  reminder (not counted as an action item) after the main summary, because fonts
  live on the local terminal, not the remote host. Resolves #27.

### Fixed
- `install.sh`: boolean assignments in `_compute_next_steps_state()` now use
  `if/then` form instead of `cmd && var=true`. The `&&` form exits with status 1
  when the condition is false, tripping `set -euo pipefail` and aborting the
  installer immediately after the git config step.

## [1.5.2] - 2026-05-06

### Fixed
- `get.sh`: on existing installs with local modifications, the installer now
  automatically stashes changes, pulls the latest, and restores the stash instead
  of aborting with a manual-steps error. Only aborts if the stash pop itself has
  merge conflicts (content disagreement requiring human judgment). Resolves #25.

## [1.5.1] - 2026-05-06

### Fixed
- `nvim/init.lua`: Mason no longer attempts to install `pyright` and
  `bash-language-server` on hosts without npm/Node.js. Both servers use npm as
  their install backend; the unconditional `ensure_installed` caused two noisy
  failure messages on every Neovim launch on GPU servers. They are now guarded
  behind `vim.fn.executable('npm') == 1`. Resolves #23.

### Changed
- `AGENTS.md`: documented the Mason npm-conditional LSP server
  guard so agents and humans know not to remove it or add new npm-dependent
  servers outside of it.

## [1.5.0] - 2026-05-05

### Added
- `nvim/init.lua`: `Wqa`, `WQa`, `WQA` command aliases mapping to `wqa`
  (write-quit-all), completing the mixed-case alias set alongside the existing
  `Wq`/`WQ` aliases. Resolves #21.
- `AGENTS.md`: new agent-facing codebase guide summarising the key rules, file
  layout, and Neovim command alias table for Codex / Copilot / other AI agents.

## [1.4.1] - 2026-05-03

### Fixed
- `_install_fzf`: skipped symlink reconciliation when `~/.fzf` already
  existed, so re-runs over partial state left `~/.local/bin/fzf` missing
  and an older system fzf could win PATH lookup - breaking modern
  `~/.fzf.zsh` integration with "unknown option: --zsh" on every shell
  startup. Now always reconciles the symlink.
- `update.sh` fzf section: same self-heal - reconciles the symlink after
  every update, fixing existing broken installs from older dotfiles
  versions without requiring a full re-install.

### Added
- `test.sh`: regression guard verifying `~/.local/bin/fzf` symlink target -
  fails CI if the symlink reconciliation is ever removed from the installer.

## [1.4.0] - 2026-04-13

### Added
- `Dockerfile.nosudo`: parameterized test image covering two no-sudo install
  scenarios, selected via build args:
  - `nosudo-auto` (`GRANT_SUDO=false`, `NOSUDO_INSTALL=""`): no `sudo` binary
    present; `detect_sudo()` auto-detects `CAN_SUDO=false` - mirrors bare Ubuntu
    containers and shared hosts without sudo
  - `nosudo-forced` (`GRANT_SUDO=true`, `NOSUDO_INSTALL=1`): user has passwordless
    `sudo` but `NOSUDO=1` overrides it - tests that the explicit env-var override
    is respected even when sudo would otherwise work
  Both variants install the `minimal` profile and land all binaries in `~/.local/bin`.

### Changed
- `modules/tmux.sh`: removed `tmux-resurrect` and `tmux-continuum` from
  `_TMUX_PLUGINS` - they were removed from `.tmux.conf.local` in v1.1.3 but the
  installer was never updated; they were being cloned on every workstation install
  without ever being sourced
- `test.sh`: comprehensive coverage improvements across all profiles:
  - **Critical fix**: nosudo `sudo -v` check was `_fail` if sudo was present -
    this always failed `nosudo-forced` (where user intentionally has sudo but
    `NOSUDO=1` overrides it). Replaced with informational `_ok` for both variants;
    the real invariant (binaries in `~/.local/bin`) is verified by `check_local_bin`
  - `check_local_bin` made strict: no longer accepts system-path binaries via
    `command -v` fallback - binary must be specifically at `~/.local/bin/<cmd>`
    so a `NOSUDO=1` regression (binary landing in `/usr/local/bin`) is caught
  - Added `delta`, `jq`, `python3` to core tools section (installed by every
    profile; were only partially or never tested)
  - Added `eza` and `shellcheck` to the minimal/workstation section
  - Added eza and delta functional smoke tests to the nosudo section
  - Added tmux plugin dir checks (`tmux-fzf`, `tmux-cpu`) for workstation profile
  - Fixed `_skip()`: used `$*` where `$1` was intended, doubling the label text
  - Fixed fd smoke test label ("can find files") to actually search files instead of
    running `--version`
  - Removed unreachable `else _fail "zoxide not installed"` (zoxide is now in
    core tools, which already catches a missing binary)
  - Added `nosudo` to the profile list in the usage comment
- `ci-local.sh` (renamed from `test-local.sh`): expanded nosudo coverage from one
  scenario to two variants (`forced` / `auto`); added `--profile nosudo-forced` and
  `--profile nosudo-auto` CLI selectors (`--profile nosudo` still selects both);
  `_run_step` gained an optional `-u USER` flag so nosudo containers run tests as
  the owning `user` rather than root; `run_nosudo` now runs the full 5-step pipeline
  (install -> test -> idempotency -> update -> re-test) matching `run_combination` for
  regular profiles; total default combinations increased from 12 to 15
- `.github/workflows/install.yml`: `install-nosudo` job expanded with
  `variant: [auto, forced]` matrix axis (3 Ubuntu × 2 variants = 6 combinations,
  up from 3); added `if: matrix.variant == 'forced'` step that installs `sudo`
  and grants passwordless access only for the `forced` variant; added
  `update.sh` step and re-test step so the no-sudo CI pipeline matches the
  regular `install` job; total CI combinations increased from 12 to 15

### Fixed
- `get.sh` / `install.sh`: `NOSUDO=1 curl ... | bash` was silently ignored because
  in a shell pipeline `VAR=val cmd1 | cmd2` the variable prefix is scoped only to
  `cmd1` (curl), not `cmd2` (bash). Both scripts now accept `--nosudo` as a CLI flag
  so the curl-pipe form works: `curl ... | bash -s -- --nosudo workstation`.
  `NOSUDO=1 bash get.sh workstation` (local-file usage) is unchanged and still works.
- `README.md`: updated nosudo one-liner to use `--nosudo` flag instead of the broken
  `NOSUDO=1 curl ...` form.
- `update.sh`: spurious `\"` in cheat URL pattern (`"linux-${cheat_arch}\""`) injected
  a literal `"` into the grep pattern, making it impossible to match the `.gz` asset
  URL. Cheat updates had been silently failing. Fixed to `"linux-${cheat_arch}.gz"`.
- `update.sh`: xcape update block used `local` and `trap ... RETURN` at script
  top-level where `RETURN` traps never fire, leaking the mktemp directory on every
  xcape rebuild. Extracted into `_do_update_xcape()` function so the trap fires
  correctly on function return.
- `modules/base.sh`: no-sudo install paths for `delta`, `ripgrep`, `fd`, and `zoxide`
  all constructed GitHub asset download URLs manually. AGENTS.md forbids this because
  asset names change between releases (delta 0.19.0 renamed its tarball). All four now
  use `_gh_release_info` to look up the actual asset URL from the API, matching the
  pattern already used by the sudo paths.
- `modules/zsh.sh` `_install_ohmyzsh`: `sh -c "$($installer)"` - if curl/wget failed,
  `sh -c ""` returned 0 and `set -e` never triggered, silently reporting success while
  oh-my-zsh was never installed. Now downloads the script into a variable with an
  explicit failure guard before passing to `sh -c`. Installer failure also now warns
  and returns instead of triggering `set -e`.
- `update.sh` oh-my-zsh update: `zsh ... || git pull` - if `git pull` (the fallback)
  failed, `set -e` exited the entire update script, leaving all remaining tools not
  updated with no warning message. Rewritten as `if/elif/else` that logs a warning
  and continues.
- `lib/utils.sh` `_download_tar_bin`: no `trap RETURN` and no `|| return 1` on the
  pipe, so a download failure triggered `set -e` exit inside the function - callers'
  `|| log_warn` handlers were never reached. Added `trap RETURN` for cleanup and
  `|| return 1` so failures propagate correctly to callers.
- `modules/neovim.sh` `install_neovim`, `update.sh` `_do_update_neovim`,
  `update.sh` `_do_update_uv`, `update.sh` cheat update,
  `modules/base.sh` `_install_eza` PPA: all had `curl | tar/gpg/gunzip` pipes with
  no error handlers. A network failure would exit the whole script mid-run with no
  user message. Each now logs a warning and returns/skips cleanly.
- `scripts/install-git.sh` / `scripts/install-cmake.sh`: `curl | tar` and `curl -o`
  download failures were silently caught by `set -euo pipefail`, exiting the script
  with no message. Both now use `|| die "..."` so network failures print an actionable
  error before exiting.
- `modules/base.sh` `_install_eza` (no-sudo path) and `_install_jq`: used
  `_gh_latest_tag_noapi` followed by manual URL construction - the same fragile
  pattern that AGENTS.md prohibits because asset names change between releases.
  Both now use `_gh_release_info` to look up the verified asset URL in one API call.

## [1.3.0] - 2026-04-11

### Added
- `scripts/install-neovim-src.sh`: standalone script to build the latest
  stable neovim from source; intended for systems where glibc < 2.32 prevents
  running prebuilt GitHub release binaries (e.g. Ubuntu 20.04); supports
  `NEOVIM_TAG` (pin version) and `NEOVIM_PREFIX` (install path) env vars

### Fixed
- `modules/neovim.sh`: detect glibc version *before* downloading - saves
  ~100 MB download on incompatible systems; fall back to v0.9.5 tarball
  (`nvim-linux64.tar.gz`, built on Ubuntu 18.04 CI, glibc 2.17+ baseline)
  when system glibc < 2.32; verify binary executes before declaring success;
  clean up any broken binary left by a prior failed install when the glibc
  fallback triggers; ARM64 systems with glibc < 2.32 fall back to apt
- `nvim/init.lua`: gate `nvim-treesitter`, `nvim-lspconfig`,
  `nvim-treesitter-context`, `mini.ai`, and `mini.bracketed` behind
  `cond = vim.fn.has('nvim-0.10') == 1` - these plugins use nvim 0.10+ APIs
  (`vim.fs.joinpath`, `LspRequest` event) or declare nvim < 0.10 soft-
  deprecated; nvim 0.9.5 now starts cleanly with regex highlighting and no LSP
- `nvim/init.lua`: use the correct post-2024 nvim-treesitter install API
  (`require('nvim-treesitter').install({...})`) - the old
  `require('nvim-treesitter.install').ensure_installed` no longer exists after
  the nvim-treesitter refactor

## [1.2.5] - 2026-04-02

### Added
- `tmux/.tmux.conf.local`: enable `bell-action any` so terminal bells from background tmux windows propagate to the status bar, triggering the existing bell tab indicator and `blink,bold` styling on the window tab

## [1.2.4] - 2026-03-23

### Fixed
- `get.sh`: existing-clone update block now fails loudly instead of silently
  continuing with a stale clone when `git pull` cannot proceed; detects and
  handles four distinct failure modes with actionable recovery instructions:
  - Stale `.git/index.lock` (interrupted git operation) - die with `rm` command
  - Unfinished merge or rebase state - die with `git status` guidance
  - Local modifications (dirty working tree) - die with full manual stash
    sequence including `exec bash` escape hatch for the case where conflict
    markers break `~/.zshrc` via symlink, and note that `get.sh` is gone after
    curl-pipe (recovery must use `bash install.sh` directly)
  - Local commits ahead of upstream - die with `git fetch && reset --hard '@{u}'`
  - Network / diverged-history pull failure - warn and continue on existing
    clone (resilient); message correctly states install proceeds on stale version
    and gives the command to apply latest changes later
- All die/warn paths consistently point to `bash <dest>/install.sh` rather than
  "re-run get.sh", which is impossible after a curl-pipe invocation

### Added
- `tmux/.tmux.conf.local`: server-local override include at end of file -
  machine-specific tmux settings now go in `~/.tmux.conf.server` (untracked,
  not in git) so `git pull` never conflicts with server customisations

## [1.2.3] - 2026-03-20

### Fixed
- `nvim/init.lua`: blink.cmp path completions truncated long names - default
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
  options - `p10k configure` (wizard, easiest), `~/.dotfiles/scripts/install-fonts.sh`
  (absolute path, works after `curl | bash` install), and a `bash <(curl ...)` one-liner
  (no local repo required); fixes confusing `./scripts/install-fonts.sh` relative path
  shown in post-install message when user is not in the dotfiles directory

## [1.2.0] - 2026-03-20

### Added
- `lib/utils.sh`: `_ver_older_than` - version comparison helper using `sort -V`
  (GNU coreutils); returns true when `$1 < $2`, false when either arg is empty
- `modules/neovim.sh`: `_nvim_warn_shadows` - detects pre-existing `nvim` copies
  at `~/.local/bin/nvim` or `~/bin/nvim` that shadow the managed install at
  `/usr/local/bin/nvim`; runs at both install time and on the skip-already-current
  path so a shadow is never silently missed
- `update.sh`: `_check_path_shadows` - PATH shadow check that always runs at the
  end of `update.sh` (read-only, no side effects); walks PATH dirs before
  `/usr/local/bin`, reports older/duplicate/newer shadows for each managed tool
  (`nvim`, `xcape`); skipped with an informational message if `/usr/local/bin` is
  not in PATH at all

### Fixed
- `modules/base.sh`: add `locales` package and `locale-gen en_US.UTF-8` to
  `install_base` - on fresh minimal Ubuntu images the locale data is absent,
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
- `tmux/.tmux.conf.local`: removed `tmux-resurrect` and `tmux-continuum` plugins - `@continuum-restore 'on'` was automatically restoring all saved sessions on every tmux launch, causing ~20 unwanted windows/panes to appear on startup

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
- `x11/caps-remap.sh`: dedicated remapping script - single source of truth for
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
  to `~/.local/share/fonts/` - no sudo required; validates downloads and
  refreshes fontconfig cache
- `scripts/install-x11.sh`: installs `xcape` from source (alols/xcape) and
  symlinks `x11/.xprofile`; applies remapping immediately and persists via
  `~/.xprofile` at next X session login
- `x11/.xprofile`: Caps Lock dual-function remapping - Ctrl when held, Escape
  when tapped alone (uses `setxkbmap` + `xcape`)
- `update.sh`: added `xcape` to known tools; rebuilds from source via
  `alols/xcape` with `--check` support and sudo guard

### Changed
- `install.sh`: post-install hints now include font and X11 remapping steps for
  `workstation` profile; docker profile notes these as local-machine-only steps
- `README.md`: added Font section (MesloLGS NF - required for icons; per-
  terminal setup instructions for GNOME Terminal, Konsole, Terminator,
  Alacritty, kitty, urxvt, VS Code); added `x11/.xprofile` to directory
  structure and symlink table; replaced demo SVG with MP4 video

## [1.0.4] - 2026-03-13

### Fixed
- `lib/utils.sh` `detect_sudo()`: rewritten as a pure probe - no output, no
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
- `get.sh`: cosmetic sudo preflight check now respects `NOSUDO=1` - no longer
  reports "✓ sudo" when sudo is explicitly disabled

### Added
- `NOSUDO=1` env var support across all entry points: forces user-local
  (`~/.local/bin`) install path and skips all apt/sudo operations even when
  `sudo` is technically available; documented in `install.sh`, `update.sh`, and
  `get.sh` usage headers
- `lib/utils.sh` `run_checks()`: profile-aware sudo footprint note - lists
  exactly which operations will use `sudo` for the active `$PROFILE`
- Per-tool pre-install disclosure in all installer modules: each tool now logs
  its target version and destination path before downloading (unified pattern
  across `modules/base.sh`, `modules/neovim.sh`, `modules/tools.sh`,
  `modules/zsh.sh`, `modules/tmux.sh`)
- `modules/base.sh`: DRY `_pkgs` arrays - single declaration drives both
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
- `_install_ripgrep`, `_install_fd`, `_install_jq` - dedicated helpers for
  no-sudo binary installs (musl tarball or single-binary releases)
- `_install_delta` / `_install_eza` - extended with no-sudo tarball path alongside
  existing `.deb` / PPA paths
- `modules/zsh.sh`: guard that skips oh-my-zsh, plugins, and zshrc setup when
  `zsh` is not available; prints actionable reinstall hint
- `test.sh`: `nosudo` profile - verifies all `~/.local/bin` binaries are present
  and functional; confirms `sudo` is absent in the test environment
- `ci-local.sh`: `--profile nosudo` flag and `--skip-nosudo` flag; `run_nosudo`
  runner builds via `Dockerfile.nosudo` and runs the nosudo test suite
- `.github/workflows/install.yml`: `install-nosudo` job - matrix across Ubuntu
  20.04 / 22.04 / 24.04 as a non-root user with no `sudo`

### Changed
- `modules/base.sh`: `install_base` restructured - apt path and no-sudo path are
  symmetric branches; prints PATH hint when binaries land in `~/.local/bin`
- `modules/base.sh` `_install_zoxide` / `_install_delta` / `_install_eza`: apt /
  `.deb` fallbacks now guarded with `$CAN_SUDO` to avoid false errors
- `lib/utils.sh`: no-sudo warning message updated to mention `~/.local/bin`

## [1.0.2] - 2026-03-12

### Removed
- `nvim`: removed `csv.vim` plugin (`chrisbra/csv.vim`) - no longer needed

## [1.0.1] - 2026-03-12

### Fixed
- `get.sh`: auto-install `git` and `curl` via `apt-get` when running as root on
  apt-based systems - bare `ubuntu:20.04` containers now need zero manual
  pre-installs (`_apt_bootstrap` helper runs `apt-get update` at most once)
- `get.sh`: sudo preflight check now correctly reports "running as root" instead
  of the misleading "apt package installs will be skipped" warning
- `modules/zsh.sh` `_set_default_shell`: `$USER` unbound variable crash in root
  containers replaced with `$(id -un)`
- `modules/zsh.sh` `_set_default_shell`: hardcoded `sudo usermod` replaced with
  `$SUDO usermod` - works on minimal images without `sudo` installed
- `modules/zsh.sh` `_set_default_shell`: `$SHELL` unbound variable crash guarded
  with `${SHELL:-}`
- `modules/zsh.sh` `_set_default_shell`: empty `zsh_path` guard prevents silent
  false-positive "already installed" and crashes on `usermod`

### Added
- `modules/zsh.sh`: `_patch_bashrc_for_docker` - when `/.dockerenv` is detected,
  appends `exec zsh` guard to `~/.bashrc` so `docker exec -it ... bash` sessions
  auto-switch to zsh; fires for all profiles including `docker`
- `install.sh`: warns when `workstation` profile is selected inside a Docker
  container, suggesting the lighter `docker` profile
- `get.sh`: Docker usage documented in header - Option A (combined one-liner) and
  Option B (`docker cp` for zero in-container pre-reqs)

## [1.0.0] - 2026-03-11

Complete overhaul of the dotfiles infrastructure: modular profiles, Neovim, CI, and bootstrap.

### Added
- `get.sh` - one-line bootstrap to install any profile on a fresh machine
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
- Tmux plugin install automated - no longer requires manual `<prefix>+I`

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

[Unreleased]: https://github.com/YASoftwareDev/dotfiles/compare/v1.4.0...HEAD
[1.4.0]: https://github.com/YASoftwareDev/dotfiles/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/YASoftwareDev/dotfiles/compare/v1.2.5...v1.3.0
[1.2.5]: https://github.com/YASoftwareDev/dotfiles/compare/v1.2.4...v1.2.5
[1.2.4]: https://github.com/YASoftwareDev/dotfiles/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/YASoftwareDev/dotfiles/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/YASoftwareDev/dotfiles/compare/v1.2.1...v1.2.2
[1.2.1]: https://github.com/YASoftwareDev/dotfiles/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/YASoftwareDev/dotfiles/compare/v1.1.3...v1.2.0
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
