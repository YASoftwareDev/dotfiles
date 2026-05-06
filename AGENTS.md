# AGENTS.md - dotfiles

This file provides codebase context for AI coding agents (Codex, Copilot, etc.).

## Repository purpose

Personal dotfiles for Ubuntu/Debian: one-command install (`install.sh`), managed
updates (`update.sh`), post-install test suite (`test.sh`), and CI matrix covering
3 Ubuntu versions × 3 install profiles + 2 no-sudo variants.

## Key files

| File | Role |
|------|------|
| `get.sh` | curl-pipe bootstrap; auto-stashes local modifications on existing clones before pulling |
| `install.sh` | Entry point - profile selection, module orchestration |
| `update.sh` | Tool updates with `--check` mode and PATH shadow detection |
| `test.sh` | Post-install validation (run after every install and update) |
| `lib/utils.sh` | Shared helpers: logging, sudo detection, GitHub release fetching |
| `modules/` | Per-concern installers: base, zsh, tmux, neovim, tools |
| `nvim/.config/nvim/init.lua` | Single-file Neovim config (lazy.nvim) |

## Critical rules (never violate)

- All scripts use `set -euo pipefail`. Use `count=$(( count + 1 ))` - never `(( count++ ))`.
  Also avoid `[ cond ] && var=true` - when the condition is false, the expression exits with 1 and
  trips `set -e`. Use `if [ cond ]; then var=true; fi` instead.
- Every function variable must be declared `local` (or `local -a` for arrays).
- Never construct GitHub release asset URLs manually - use `_gh_release_info` or
  `_gh_latest_release` from `lib/utils.sh`; asset names change between releases.
- Never use `command -v` at install time to probe binary locations - use direct
  `[ -x /absolute/path ]` probes.
- Never commit generated protobuf files (`*_pb2.py`, `*.pb.go`, etc.).
- Logging: `log_step`, `log_info`, `log_ok`, `log_warn`, `log_error`, `die` - never bare `echo`.

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

## Version bump rules

- `fix:` commits -> patch (`X.Y.Z+1`)
- `feat:` commits -> minor (`X.Y+1.0`)
- `BREAKING CHANGE` -> major (`X+1.0.0`)

Edit `VERSION`, update `CHANGELOG.md`, commit as `chore: release vX.Y.Z`, tag
`vX.Y.Z` on the merge commit on `master`.
