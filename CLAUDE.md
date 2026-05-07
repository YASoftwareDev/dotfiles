# CLAUDE.md — dotfiles

## Repository purpose

Personal dotfiles for Ubuntu/Debian. One-command install (`install.sh`) with four
profiles, managed updates (`update.sh`), and a post-install test suite (`test.sh`).
CI tests all profile × Ubuntu-version combinations on every push.

---

## Directory layout

```
install.sh        entry point — profile selection, module orchestration
update.sh         managed tool updates with --check mode + PATH shadow check
test.sh           post-install validation suite (profile-aware)
ci-local.sh       local Docker matrix runner — mirrors GitHub CI matrix
get.sh            curl-pipe bootstrap (clones repo → runs install.sh);
                  on existing clones auto-stashes local modifications, pulls,
                  then restores the stash — only aborts on stash-pop conflicts
Dockerfile        bakes docker profile into an image at build time
Dockerfile.nosudo parameterized no-sudo test image (two variants: forced/auto)
lib/utils.sh      shared logging, sudo detection, GitHub helpers, binary utils
modules/
  base.sh         apt packages + per-tool installers (fzf, zoxide, delta, eza, …)
  zsh.sh          oh-my-zsh, plugins, .zshrc symlink, default shell
  tmux.sh         tmux config symlinks, plugin cloning
  neovim.sh       GitHub binary release, config symlink, shadow detection
  tools.sh        uv, ruff, cheat, ripgrep/ranger config
scripts/
  install-fonts.sh   MesloLGS NF installer (local workstation only)
  install-x11.sh     Caps Lock remapping (X11 only)
zsh/              .zshrc
nvim/             .config/nvim/ (lazy.nvim, LSP, treesitter, etc.)
git/              .gitconfig, .gitattributes
tmux/             .tmux.conf, .tmux.conf.local
ripgrep/          .config/ripgrep/rc
ranger/           .config/ranger/ (individual file symlinks, not directory)
x11/              .xprofile, caps-remap.sh, autostart .desktop
VERSION           semver string
CHANGELOG.md      keep-a-changelog format
```

`DOTFILES_DIR` is set at the top of every script to the absolute repo root:
```bash
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
```
Use it whenever referencing files inside the repo — never use relative paths.

---

## Install profiles

Three profiles are valid `install.sh` arguments:

| Profile | Sudo | Installs |
|---------|------|----------|
| `minimal` | required for apt | base pkgs, zsh, tmux, git config |
| `workstation` | required for apt | minimal + neovim + tools (uv, ruff, cheat) |
| `docker` | optional | base pkgs, zsh, tmux, git config (no shell change) |

Profile selection: CLI arg → interactive wizard (tty only) → workstation default.

**No-sudo mode** is not a profile — it is an environment flag:
```bash
NOSUDO=1 ./install.sh minimal   # forces CAN_SUDO=false; tools fetched to ~/.local/bin
```
`nosudo` appears as a profile name only in `test.sh`, where it validates that
the no-sudo install produced the correct binaries in `~/.local/bin`.

Module orchestration in `install.sh`:
- `_run_minimal`      → base → zsh → tmux → git link
- `_run_workstation`  → base → zsh → tmux plugins → tools → neovim → git link
- `_run_docker`       → base\_docker → zsh (no shell change) → tmux → git link

---

## Logging

```bash
log_step "Section name"   # bold header: ── Section name ──
log_info "message"        # blue →
log_ok   "message"        # green ✓
log_warn "message"        # yellow !  — already writes to stderr internally
log_error "message"       # red ✗    — already writes to stderr internally
die "message"             # log_error + exit 1
```

`log_warn` and `log_error` redirect to stderr inside the function — do NOT add
`>&2` at call sites. Always use these; never `echo` directly.

---

## Shell scripting rules

**`set -euo pipefail`** — all scripts use strict mode. Key implications:
```bash
# WRONG — (( expr )) exits with status 1 when result is 0 (falsy), triggers set -e
(( count++ ))

# CORRECT
count=$(( count + 1 ))

# WRONG — cmd && var=true exits 1 when cmd is false (condition not met), triggers set -e
[ -f ~/.p10k.zsh ] && CONFIGURED=true

# CORRECT — if/then consumes the condition exit code without propagating it
if [ -f ~/.p10k.zsh ]; then CONFIGURED=true; fi
```

**`local` declarations** — every variable inside a function MUST be declared
`local` (or `local -a` for arrays). Undeclared variables leak into global scope
and can corrupt state when functions are called multiple times or sourced.

```bash
my_func() {
    local var="value"
    local -a arr=()
    local result
    result=$(some_command)
}
```

---

## Sudo handling

`detect_sudo` (called once early) sets three globals:

```bash
SUDO=""/"sudo"          # prefix for privileged commands
CAN_SUDO=true/false     # boolean for branching
SUDO_STATUS=root|sudo_passwordless|sudo_password|nosudo
```

Patterns:
```bash
if $CAN_SUDO; then
    $SUDO apt-get ...
fi

# Refresh credential cache before long operations (download may take >15 min)
[ -n "${SUDO:-}" ] && sudo -v 2>/dev/null || true
```

---

## Tool install pattern (apt-first / GitHub fallback)

```
CAN_SUDO + apt has it? → apt_install
CAN_SUDO + apt missing? → GitHub .deb (via _gh_release_info) or PPA
no sudo? → GitHub tarball → ~/.local/bin
```

Key helpers in `lib/utils.sh`:

| Function | Purpose |
|----------|---------|
| `has CMD` | `command -v` wrapper |
| `apt_install` | apt-get with DEBIAN_FRONTEND=noninteractive |
| `_gh_latest_tag_noapi REPO` | Tag via HTTP redirect — **prefer this** (no API, no rate limit) |
| `_gh_latest_tag REPO` | Tag via GitHub JSON API — use only when redirect fails |
| `_gh_latest_release REPO PATTERN` | Download URL matching asset pattern |
| `_gh_release_info REPO PATTERN` | Tag + URL in one API call → `"TAG URL"` — use when you need both |
| `_download_tar_bin URL BIN DEST` | Download tarball, extract named binary |
| `_cmd_version CMD [ARGS]` | Extract `\d+\.\d+(\.\d+)?` from `--version` |
| `_ver_older_than A B` | True if A < B via `sort -V` |
| `_verify_dest BIN DEST` | Warn if `command -v BIN` ≠ DEST |
| `_resolve_dest BIN FALLBACK` | Use current binary location; never `/usr/*` |
| `symlink SRC DST` | `mkdir -p + ln -sf` |

**When to use which GitHub helper:**
- Tag only, no download → `_gh_latest_tag_noapi` (no API call)
- Tag + URL together → `_gh_release_info` (one API call)
- URL only (pattern match) → `_gh_latest_release`
- **Never construct `.deb` URLs manually** — asset names change between releases
  (e.g. delta 0.19.0 renamed `git-delta` → `git-delta-musl`); use `_gh_release_info`

---

## update.sh

**Two modes:**
```bash
./update.sh             # update all tools
./update.sh --check     # report current vs latest (read-only)
./update.sh rg neovim   # update only named tools
```

**Known tools list** — `_KNOWN_TOOLS` array at the top of `update.sh`:
```
apt omz tmux-plugins zsh-plugins fzf rg fd shellcheck
zoxide delta eza uv ruff neovim cheat pre-commit xcape
```
**When adding a new tool, add its name here** — the arg parser rejects unknown names.

**`_should_run` pattern** used at the top of each tool block:
```bash
_should_run "toolname" || return 0
```

**`_update_plugin NAME PATH [URL]`** — git-pull a cloned plugin. When the directory is
missing and `URL` is provided, clones it instead of skipping. Pass the URL for zsh plugins
(see update.sh `zsh-plugins` block) so that `update.sh zsh-plugins` self-heals a machine
that received the dotfiles after a plugin was added.

**`_update_std_tool` helper** covers standard single-binary GitHub tarball tools:
```bash
# Usage: _update_std_tool CMD LABEL REPO GNU_ARM [BINARY] [ASSET_PREFIX]
_update_std_tool rg    "ripgrep" "BurntSushi/ripgrep" gnu
_update_std_tool eza   "eza"     "eza-community/eza"  musl eza "eza_"
```

**PATH shadow check** (`_check_path_shadows`) always runs at the end, read-only.

---

## Architecture triples

```bash
# Rust tools (most tools)
x86_64)  arch="x86_64-unknown-linux-musl" ;;
aarch64) arch="aarch64-unknown-linux-gnu"  ;;  # or musl depending on tool

# Debian arch (for .deb)
_deb_arch()   # dpkg --print-architecture; fallback: x86_64→amd64, aarch64→arm64

# Bare (shellcheck)
x86_64 / aarch64
```

Always handle unsupported arch with `log_warn "... — skipping"; return`.

---

## Tmpdir cleanup

```bash
local tmp; tmp=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" RETURN   # RETURN fires on explicit return AND implicit exit
```

`SC2064` is disabled intentionally — `$tmp` must expand at trap-definition time
(it is a local variable; expanding later would find it unset). Use `RETURN` not
`EXIT` so the trap is function-scoped, not script-scoped.

---

## PATH shadow detection

Two surfaces:

1. **Install time** (`modules/neovim.sh` `_nvim_warn_shadows`): direct file probes
   on `$HOME/.local/bin/nvim` and `$HOME/bin/nvim` — never `command -v`, which
   resolves via install-time bash PATH and may itself return a shadow binary.

2. **Update time** (`update.sh` `_check_path_shadows`): PATH walk looking for
   executables before `/usr/local/bin`. Runs always, read-only.

Only `/usr/local/bin` tools need shadow checks — tools at `~/.local/bin` are
already at the highest dotfiles-managed PATH priority.

---

## Symlink layout

| Dotfiles path | Linked to |
|---------------|-----------|
| `zsh/.zshrc` | `~/.zshrc` |
| `tmux/.tmux.conf` | `~/.tmux.conf` |
| `tmux/.tmux.conf.local` | `~/.tmux.conf.local` |
| `nvim/.config/nvim` | `~/.config/nvim` (directory symlink) |
| `git/.gitconfig` | `~/.gitconfig` |
| `git/.gitattributes` | `~/.gitattributes` |
| `git/.gitconfig.local.example` | reference only — copy to `~/.gitconfig.local` and fill in name/email/credentials (never committed; included at end of `.gitconfig` so it can override anything) |
| `zsh/.zshrc.local.example` | reference only — copy to `~/.zshrc.local`; sourced at end of `.zshrc` |
| `tmux/.tmux.conf.server.example` | reference only — copy to `~/.tmux.conf.server`; sourced at end of `.tmux.conf.local` |
| `nvim/.config/nvim/local.lua.example` | reference only — copy to `~/.config/nvim/local.lua`; sourced at end of `init.lua` via `dofile` if readable |
| `ripgrep/rc` | `~/.config/ripgrep/rc` |
| `ranger/rc.conf`, `rifle.conf`, `scope.sh`, `commands*.py` | `~/.config/ranger/` (individual files) |
| `x11/.xprofile` | `~/.xprofile` |
| `x11/.config/autostart/caps-remap.desktop` | `~/.config/autostart/caps-remap.desktop` |

Ranger is linked file-by-file (not as a directory) to keep runtime state
(`bookmarks`, `history`, `tags`) out of git.

Nvim: if `~/.config/nvim` is a real directory (not a symlink), `link_nvim_config`
warns and bails rather than creating a link inside it.

---

## Neovim config

`nvim/.config/nvim/init.lua` is a single-file config using lazy.nvim.

**Command aliases** — the bottom of `init.lua` registers mixed-case variants of
common Ex commands so accidental Shift-holding doesn't fail:

| Typed | Runs |
|-------|------|
| `W` | `w` |
| `Wq`, `WQ` | `wq` |
| `Wqa`, `WQa`, `WQA` | `wqa` |
| `Q` | `q` |
| `Qa`, `QA` | `qa` |

Add new aliases to the `pairs({…})` table at the bottom of `init.lua` — one line,
no per-command boilerplate.

**Mason LSP servers** — `pyright` and `bash-language-server` are installed by
Mason via npm. The config guards them behind `vim.fn.executable('npm') == 1` so
`ensure_installed` only includes them when npm is present on the host. Hosts
without Node.js (e.g. GPU servers) still get `clangd` and `lua_ls` (no npm
needed). Do not remove this guard or add other npm-dependent servers without
wrapping them in the same check.

---

## fzf integration

fzf is installed via **git clone** to `~/.fzf/` (not apt, not a binary release).
The installer generates `~/.fzf.zsh` which contains `source <(fzf --zsh)` (modern
fzf integration, fzf ≥ 0.48) and is sourced **explicitly** in `.zshrc`:
```bash
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh
```
The oh-my-zsh `fzf` plugin was removed — this explicit source line is the **only**
thing that activates fzf shell integration. Do not remove it. Do not re-add the
oh-my-zsh `fzf` plugin without removing this line first.

**Load-bearing invariant**: `~/.local/bin/fzf` must symlink to `~/.fzf/bin/fzf`.
Because `~/.fzf.zsh` calls `fzf --zsh` at shell startup, an older system fzf at
`/usr/local/bin/fzf` or `/usr/bin/fzf` shadowing the managed install will print
`unknown option: --zsh` on every login. `_install_fzf` in `modules/base.sh` and
the fzf section of `update.sh` both **always reconcile this symlink** (idempotent
`ln -sf` after the existence check), even when the clone is already present —
so re-runs over partial state self-heal. `test.sh` carries a regression guard.

---

## Global flags

| Flag | Set by | Read by |
|------|--------|---------|
| `_SHELL_IS_ZSH` | `_set_default_shell()` in `modules/zsh.sh` | logging during install (not used by next-steps summary) |
| `NXS_*` | `_compute_next_steps_state()` in `install.sh` | `install.sh` "next steps" — reads actual system state (passwd, ZSH_VERSION, fc-list, …) rather than install-time flags; `NXS_STDIN_IS_TTY` gates "exec zsh" advice that is noise in curl-pipe / CI contexts |
| `CAN_SUDO` | `detect_sudo()` in `lib/utils.sh` | everywhere |
| `CHECK_ONLY` | `--check` arg in `update.sh` | update.sh per-tool blocks |
| `DOTFILES_DIR` | top of each script | modules, symlink helpers |

---

## Idempotency rules

- Check before installing: `has cmd && { log_ok "already installed"; return; }`
- Check before cloning: `[ -d dest ] && return`
- Locale: `locale -a | grep -q 'en_US.utf8'` guard before `locale-gen`
- `apt_install` is naturally idempotent

---

## test.sh

```bash
bash test.sh [docker|minimal|workstation|nosudo]
```

Exits 0 (all pass), 1 (any fail). Skips are not failures.
Runs in CI after every install + again after update.sh.

Core checks (all profiles): zsh, tmux, git, python3, fzf, ripgrep, git-delta,
zoxide, jq, fd; fzf shell integration + functional filter; zsh syntax check;
oh-my-zsh + plugins + powerlevel10k dirs; tmux detached session start; git config
diff driver; zoxide init + add + query.

Profile-specific checks:
- `workstation` — nvim, uv, cheat; config symlinks (nvim, ripgrep, ranger);
  tmux plugin dirs (tmux-fzf, tmux-cpu)
- `minimal` — ranger, tig, parallel, eza, shellcheck (all via apt)
- `nosudo` — strict `~/.local/bin` presence check for all 7 GitHub binaries
  (rg, fd, jq, fzf, zoxide, delta, eza); sudo availability info (not a failure
  condition — nosudo-forced has sudo available); functional smoke tests for each

Two nosudo scenarios are validated by `Dockerfile.nosudo`:
- **nosudo-auto** — no `sudo` binary; `detect_sudo()` auto-detects `CAN_SUDO=false`
  (`GRANT_SUDO=false NOSUDO_INSTALL=""` build args)
- **nosudo-forced** — user has passwordless `sudo` but `NOSUDO=1` overrides it
  (`GRANT_SUDO=true NOSUDO_INSTALL=1` build args)

---

## CI matrix

**Job `install`** (9 combinations):
- Ubuntu 20.04 / 22.04 / 24.04 × docker / minimal / workstation
- testuser with passwordless sudo; curl auth via `~/.curlrc`
- Flow: install → idempotency re-run → test → update → re-test

**Job `install-nosudo`** (6 combinations — 3 Ubuntu × 2 variants):
- Ubuntu 20.04 / 22.04 / 24.04 × variant `auto` / `forced`
- Root pre-installs: git, curl, wget, ca-certificates, zsh, tmux, python3
- `auto`: no `sudo` binary installed; `detect_sudo()` auto-detects `CAN_SUDO=false`
- `forced`: passwordless `sudo` installed, but `NOSUDO=1` overrides it
- Flow: install → test → idempotency re-run → update → re-test

**Total: 15 CI combinations** (9 regular + 6 nosudo)

---

## Versioning & release

```
1. Edit VERSION — bump semver (patch: fix, minor: feature, major: breaking)
2. Edit CHANGELOG.md — move items from [Unreleased] to [X.Y.Z] - YYYY-MM-DD
3. git add VERSION CHANGELOG.md && git commit -m "docs: bump version to X.Y.Z"
4. git tag vX.Y.Z
5. git push origin master && git push origin vX.Y.Z
6. gh release create vX.Y.Z --title "vX.Y.Z" --notes "..."
```

---

## What NOT to do

- **Never construct GitHub release asset URLs from version + arch** — use
  `_gh_release_info` or `_gh_latest_release`; asset names change between releases.
- **Never use `command -v` at install time** when PATH order matters — use direct
  `[ -x /absolute/path ]` probes (install-time bash PATH may resolve to shadow).
- **Never `git push` without confirmation** — always ask first.
