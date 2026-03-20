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
get.sh            curl-pipe bootstrap (clones repo → runs install.sh)
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

---

## Install profiles

| Profile | Sudo | Installs | Notes |
|---------|------|----------|-------|
| `minimal` | required | base pkgs, zsh, tmux, git config | Terminal baseline |
| `workstation` | required | minimal + neovim + tools (uv, ruff, cheat) | Full dev setup |
| `docker` | optional | base pkgs, zsh, tmux, git config | No shell change, no fonts |
| `nosudo` | none | all tools fetched to `~/.local/bin` | `NOSUDO=1 ./install.sh minimal` |

Profile selection: CLI arg → interactive wizard (tty only) → workstation default.

Module orchestration in `install.sh`:
- `_run_minimal`      → base → zsh → tmux → git link
- `_run_workstation`  → base → zsh → tmux plugins → tools → neovim → git link
- `_run_docker`       → base\_docker → zsh(no shell change) → tmux → git link

---

## Logging

```bash
log_step "Section name"   # bold header: ── Section name ──
log_info "..."            # blue →
log_ok   "..."            # green ✓
log_warn "..." >&2        # yellow !  (stderr)
log_error "..." >&2       # red ✗     (stderr)
die "..."                 # log_error + exit 1
```

Always use these — never `echo` directly.

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

# Refresh credential cache before long operations
sudo -v 2>/dev/null || true

# Environment override
NOSUDO=1 ./install.sh minimal   # forces CAN_SUDO=false everywhere
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
| `_gh_latest_tag_noapi REPO` | Tag via HTTP redirect (no API, no rate limit) |
| `_gh_latest_tag REPO` | Tag via GitHub JSON API |
| `_gh_latest_release REPO PATTERN` | Download URL matching pattern |
| `_gh_release_info REPO PATTERN` | Tag + URL in one API call → `"TAG URL"` |
| `_download_tar_bin URL BIN DEST` | Download tarball, extract named binary |
| `_cmd_version CMD [ARGS]` | Extract `\d+\.\d+(\.\d+)?` from `--version` |
| `_ver_older_than A B` | True if A < B via `sort -V` |
| `_verify_dest BIN DEST` | Warn if `command -v BIN` ≠ DEST |
| `_resolve_dest BIN FALLBACK` | Use current binary location; never `/usr/*` |
| `symlink SRC DST` | `mkdir -p + ln -sf` |

**Use `_gh_release_info` (not URL construction) for `.deb` assets** — asset names
change between releases (e.g. delta 0.19.0 renamed `git-delta` → `git-delta-musl`).

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

Use `RETURN` (not `EXIT`) so the trap is function-scoped, not script-scoped.

---

## PATH shadow detection

Two surfaces:

1. **install time** (`modules/neovim.sh` `_nvim_warn_shadows`): direct file probes
   (`[ -e "$HOME/.local/bin/nvim" ]`) — never `command -v`, which resolves via
   install-time bash PATH and may return a shadow binary.

2. **update time** (`update.sh` `_check_path_shadows`): PATH walk looking for
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
| `ripgrep/rc` | `~/.config/ripgrep/rc` |
| `ranger/*.conf` | `~/.config/ranger/*.conf` (individual files) |
| `x11/.xprofile` | `~/.xprofile` |

Ranger is linked file-by-file (not as a directory) to keep runtime state
(`bookmarks`, `history`, `tags`) out of git.

Nvim: if `~/.config/nvim` is a real directory (not a symlink), `link_nvim_config`
warns and bails rather than creating a link inside it.

---

## Global flags

| Flag | Set by | Read by |
|------|--------|---------|
| `_SHELL_IS_ZSH` | `_set_default_shell()` in `modules/zsh.sh` | `install.sh` "next steps" |
| `CAN_SUDO` | `detect_sudo()` in `lib/utils.sh` | everywhere |
| `CHECK_ONLY` | `--check` arg in `update.sh` | update.sh per-tool blocks |

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

Profile-specific checks:
- `workstation` — nvim, delta, uv, cheat, config symlinks
- `minimal` — ranger, tig, parallel
- `nosudo` — all `~/.local/bin` binaries present + sudo NOT available

---

## CI matrix

**Job `install`** (9 combinations):
- Ubuntu 20.04 / 22.04 / 24.04 × docker / minimal / workstation
- testuser with passwordless sudo; curl auth via `~/.curlrc`
- Flow: install → idempotency re-run → test → update → re-test

**Job `install-nosudo`** (3 combinations):
- Ubuntu 20.04 / 22.04 / 24.04
- Root pre-installs: git, curl, wget, ca-certificates, zsh, tmux, python3
- Regular user with no sudo; `NOSUDO` path exercised

---

## Versioning & release

- `VERSION` — semver (e.g. `1.2.2`)
- `CHANGELOG.md` — keep-a-changelog; update `[Unreleased]` section then add `[X.Y.Z] - DATE`
- Tags: `vX.Y.Z`
- Patch: bug fixes. Minor: new features. Major: breaking changes.

---

## What NOT to do

- **Never construct GitHub release asset URLs from version + arch** — use
  `_gh_release_info` or `_gh_latest_release` to get the actual URL; names change.
- **Never use `command -v` to check for binaries at install time** when PATH order
  matters — use absolute paths or direct `[ -x /path/to/bin ]` probes.
- **Never commit generated files** (`*_pb2.py`, `*.pb.go`, etc.) — not relevant
  here but applies if protobuf ever appears.
- **Never `git push` without confirmation** — always ask first.
- **Never add Co-Authored-By: Claude** to commit messages.
- **Never skip hooks** (`--no-verify`) or force-push master.
