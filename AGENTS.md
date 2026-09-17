# AGENTS.md - dotfiles

This file provides codebase context for AI coding agents (Codex, Copilot, etc.).

## Repository purpose

Personal dotfiles for Ubuntu/Debian, with RHEL-family (AlmaLinux/Rocky/Fedora)
support via the user-local binary path: one-command install (`install.sh`),
managed updates (`update.sh`), post-install test suite (`test.sh`), and CI
matrix covering 3 Ubuntu versions × 3 install profiles + no-sudo variants
(auto / forced / nonsudoer) on 3 Ubuntu + 2 AlmaLinux versions, plus the nvim
config on pinned nvim 0.10 and 0.11 - 26 cells total.

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
