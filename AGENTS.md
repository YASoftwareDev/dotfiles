# AGENTS.md - dotfiles

This file provides codebase context for AI coding agents (Codex, Copilot, etc.).

## Repository purpose

Personal dotfiles for Ubuntu/Debian, with RHEL-family (AlmaLinux/Rocky/Fedora)
support via the user-local binary path: one-command install (`install.sh`),
managed updates (`update.sh`), post-install test suite (`test.sh`), and CI
matrix covering 3 Ubuntu versions × 3 install profiles + no-sudo variants
(auto / forced / nonsudoer) on 3 Ubuntu + 2 AlmaLinux versions, plus the nvim
config on pinned nvim 0.10 and 0.11, the latter both with and without build
tools, and one Ubuntu 16.04 cell whose git 2.7.4 exercises the full-clone
fallback and the unapplied-pins path - 28 cells total.

## Key files

| File | Role |
|------|------|
| `get.sh` | curl-pipe bootstrap; auto-stashes local modifications on existing clones before pulling |
| `install.sh` | Entry point - profile selection, module orchestration |
| `update.sh` | Tool updates with `--check` mode, PATH shadow detection, and plugin auto-heal |
| `test.sh` | Post-install validation (run after every install and update) |
| `lib/utils.sh` | Shared helpers: logging, sudo detection (`detect_sudo` uses `sudo -n -v` to tell a real sudoer from a user not in sudoers), GitHub release fetching |
| `modules/` | Per-concern installers: base, zsh, tmux, neovim, tools |
| `nvim/.config/nvim/init.lua` | Single-file Neovim config (lazy.nvim) |

## Critical rules (never violate)

- Gate every apt code path on `$CAN_APT` (sudo AND apt-get present, set by
  `detect_sudo`), never on `$CAN_SUDO` alone - on RHEL-family systems sudo can be
  available while apt is not, and a bare `apt-get` call dies under `set -e`.
  Applies to the install/update flow; the optional `scripts/` desktop helpers
  are Ubuntu-only.
- All scripts use `set -euo pipefail`. Use `count=$(( count + 1 ))` - never `(( count++ ))`.
  Also avoid `[ cond ] && var=true` - when the condition is false, the expression exits with 1 and
  trips `set -e`. Use `if [ cond ]; then var=true; fi` instead.
- Every function variable must be declared `local` (or `local -a` for arrays).
- A tool whose Debian package renames the binary needs a SHIM, or the installer
  skips it forever: `has bat` is false when apt supplied `batcat`, exactly as with
  `fd`/`fdfind`. Add the shim in the same change as the installer, in BOTH
  `install_base` and `install_base_docker` - and note the docker branch needs it
  even though its apt list does not ask for the package, since a base image may
  already carry the renamed binary.
- **Run `bash tests/lint-workflows.sh` before pushing a workflow change.** An
  invalid workflow runs nothing, so CI cannot report the fault, and with
  `CI gate` required the PR blocks with no visible cause. It catches the two
  that cost runs on PR #52: a double-quoted string inside an expression (only
  single quotes are legal), and the expression delimiters written in a comment -
  GitHub scans comments too, and an empty pair is itself a syntax error.
- `CI gate` is the single required status check on `master`, and it `needs` every
  other job. **Add any new job to its `needs`** - the gate asserts its own
  completeness and fails when a job sits outside it, because a job nobody
  required would lose coverage while CI stayed green.
- Never let an apt call abort the install. A package name that does not exist on
  an older release makes apt exit 100, and `set -e` then kills the whole run -
  measured on Ubuntu 18.04, where `ripgrep`/`fd-find` are absent. Install a bulk
  list with a per-package retry, keep an optional tool's apt steps non-fatal
  (`|| { log_warn ...; return; }`), and let the `_install_*` GitHub fallbacks
  cover whatever apt cannot supply.
- **`~/.gitconfig` is a SYMLINK to the tracked `git/.gitconfig`.** Never run a command
  that writes global git config (`git lfs install`, `git config --global`) from the
  install: it edits a tracked file and leaves every host's checkout dirty, which then
  blocks its own next update. Machine-specific git settings go to `~/.gitconfig.local`
  conditionally, as the zdiff3 and git-lfs branches in `_link_git_config` do.
- **Do not configure what is not installed** (`tests/config-needs-tool.py` enforces
  it: every linked config dir must declare `installer`, `guarded`, or `prerequisite`
  with a reason, and an undeclared one fails).
- **Do not configure what is not installed.** `install_zsh` and `install_tmux` both
  return early with an actionable warning when their binary is absent; a host that
  looks configured while nothing can use it is how the no-sudo tmux gap stayed
  invisible. Guard EVERY entry point, not just the first: install.sh chains
  `install_tmux && _install_tmux_plugins`, and the early return must exit 0 or
  `set -e` kills the run - so the chained function needs its own guard.
- **Never let a test environment supply the thing under test** (`tests/no-fixture-masking.py` enforces this for tools with an `_install_*` function; it cannot see a tool the repo ships config for but never installs, which is what the original gap was). The no-sudo CI jobs
  and `Dockerfile.nosudo` pre-installed tmux as a root prerequisite, so `has tmux`
  was true before install.sh ran. A non-sudoer therefore got tmux CONFIG and tmux
  PLUGINS but no tmux BINARY, and 15 green cells said nothing about it for months -
  found on a real host, not in CI. When adding a prerequisite to a test image, ask
  whether the install is supposed to provide it; if it is, leave it out.
- Never construct GitHub release asset URLs manually - use `_gh_release_info` or
  `_gh_latest_release` from `lib/utils.sh`; asset names change between releases.
  Exception: `releases/latest/download/<name>` for an asset whose name carries no
  version (yazi, cheat, uv, tree-sitter) - no API call, no rate limit.
- Never use `command -v` at install time to probe binary locations - use direct
  `[ -x /absolute/path ]` probes.
- Never commit generated protobuf files (`*_pb2.py`, `*.pb.go`, etc.).
- Logging: `log_step`, `log_info`, `log_ok`, `log_warn`, `log_error`, `die` - never bare `echo`.
- Read the glibc version with `_glibc_version`, never `ldd --version | head -1 ... || echo 0.0`:
  under pipefail ldd can take SIGPIPE and the fallback corrupts the value (measured 52/200
  runs on Ubuntu 20.04), which installed nvim builds that cannot run there.

## Neovim config

`nvim/.config/nvim/init.lua` registers mixed-case Ex command aliases at the bottom
of the file so accidental Shift-holding doesn't fail:

```
W → w    Wq/WQ → wq    Wqa/WQa/WQA → wqa    Q → q    Qa/QA → qa
```

Add new aliases to the `pairs({...})` table - one line, no boilerplate.

**Mason LSP servers** - `pyright` and `bash-language-server` are npm-based.
They are wrapped in `vim.fn.executable('npm') == 1` so hosts without npm (e.g.
GPU servers) skip them silently. Do not remove this guard or add new npm-dependent
servers outside of it.

**`fzf_ok`** guards `telescope-fzf-native`, a C library: it gates that dependency's
`cond` and the `load_extension('fzf')` call on `make` plus a compiler. Without it
the failed load aborted telescope's whole `config`, so every telescope key was dead
on an nvim 0.11+ host with no build tools. Telescope's own sorter is the fallback.
Same rule as the npm guard - do not remove it, and keep optional native extensions
behind it.

**`truecolor_ok`** gates `termguicolors` and NOTHING else - it must never switch the
colorscheme. nightfly sets only gui colours, so forcing `termguicolors` on a chain
that cannot deliver 24-bit colour left nothing readable (#53).

Two rules, both measured 2026-09-18 and both easy to get wrong:

- **Judge the chain, not `$TERM`.** Inside tmux `$TERM` is always tmux's own
  (`tmux-256color`) and says nothing about the client; tmux quantizes whatever nvim
  emits down to the attached client's palette. So `_chain_colors()` asks tmux for
  `#{client_termname}` and counts that terminal's colours with `tput -T`. Counting
  beats name-matching: alacritty and xterm-kitty are truecolor terminals whose names
  carry no `256`.
- **Do not "improve" the fallback by switching scheme.** habamax and retrobox set
  256-colour greys (`ctermfg=251`/`ctermbg=234`) which BOTH collapse to black when
  quantized to 8 colours - measured 67% of the screen black-on-black, far worse than
  the bug. Leaving nightfly with `termguicolors` off renders in the terminal's own
  fg/bg: 0.4% unreadable against 9.8% before the fix.

`tests/nvim-colour-fallback.sh` pins all four arms, including the tmux one.

**Version gates** - supported hosts run nvim 0.9-0.12. Options and plugins that need a
newer nvim are gated (`vim.fn.has('nvim-0.X')`, lazy `cond`), because one invalid
option value aborts the rest of init.lua. Parser installs are gated on nvim 0.12,
a `tree-sitter` CLI >= 0.26.1, a C compiler (`$CC`'s first word), curl and tar (what
nvim-treesitter needs to build them);
nvim-treesitter itself still loads from 0.10, as on master.

## update.sh helpers

- **`_update_plugin NAME PATH [URL]`** - pulls the plugin at `PATH`; if `PATH` is missing and
  `URL` is given, clones it. The zsh-plugins block passes URLs so `update.sh zsh-plugins`
  can self-heal machines that missed a plugin install.
- **`_update_std_tool CMD LABEL REPO GNU_ARM [BINARY] [ASSET_PREFIX]`** - covers standard
  single-binary GitHub tarball tools (rg, eza, fd, ...).

## Version bump rules

- `fix:` commits -> patch (`X.Y.Z+1`)
- `feat:` commits -> minor (`X.Y+1.0`)
- `BREAKING CHANGE` -> major (`X+1.0.0`)

Edit `VERSION`, update `CHANGELOG.md`, commit as `chore: release vX.Y.Z`, tag
`vX.Y.Z` on the merge commit on `master`.
