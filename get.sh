#!/usr/bin/env bash
# YA Dotfiles — one-line bootstrap
#
# Usage (pick a flavor):
#
#   workstation (full setup — no wizard when piped):
#     curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash -s -- workstation
#
#   minimal (zsh + tmux + git config only):
#     curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash -s -- minimal
#
#   docker (headless, CI-friendly, no shell change):
#     curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash -s -- docker
#
#   force user-local installs (no apt, ~/.local/bin only) — useful on shared machines:
#     NOSUDO=1 bash get.sh workstation
#     (NOSUDO=1 is forwarded automatically to install.sh via exec)
#
# Or inspect first, then run (also gives you the interactive wizard):
#   curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh -o get.sh
#   bash get.sh [minimal|workstation|docker]
#
# Docker (clean Ubuntu container):
#   Option A — single copy-paste command (installs curl, then runs get.sh):
#     apt-get update -qq && apt-get install -yq curl && \
#       curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash -s -- workstation
#
#   Option B — if you already have get.sh locally (auto-installs git+curl inside container):
#     docker cp get.sh <container>:/get.sh
#     docker exec <container> bash /get.sh workstation
#
# Note: the interactive profile wizard requires a real terminal (stdin = tty).
#       When piping through bash, a profile argument is required.
#

set -euo pipefail

REPO="https://github.com/YASoftwareDev/dotfiles.git"
DEST="${DOTFILES_DIR:-$HOME/.dotfiles}"
PROFILE="${1:-}"

# ── Colour helpers ─────────────────────────────────────────────────────────────
BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
_info()  { echo -e "${BOLD}  →${NC} $*"; }
_ok()    { echo -e "${GREEN}  ✓${NC} $*"; }
_warn()  { echo -e "${YELLOW}  !${NC} $*" >&2; }
_die()   { echo -e "${RED}  ✗${NC} $*" >&2; exit 1; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗"
echo -e "║      YA Dotfiles — Bootstrap             ║"
echo -e "╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Enforce explicit profile when piped (no tty = no wizard) ──────────────────
if [ -z "$PROFILE" ] && [ ! -t 0 ]; then
    _die "Profile required when piping. Use: bash -s -- <minimal|workstation|docker>"
fi

# ── Pre-flight checks ──────────────────────────────────────────────────────────
echo -e "${BOLD}── Pre-flight checks ──${NC}"
_preflight_ok=true

# auto-bootstrap missing tools when running as root on apt-based systems
_apt_updated=false
_apt_bootstrap() {
    local pkg="$1"
    if [ "$(id -u)" -ne 0 ] || ! command -v apt-get &>/dev/null; then
        return 1
    fi
    if ! $_apt_updated; then
        apt-get update -qq >/dev/null
        _apt_updated=true
    fi
    DEBIAN_FRONTEND=noninteractive apt-get install -yq "$pkg" >/dev/null
}

# git (hard requirement — needed to clone)
if command -v git &>/dev/null; then
    _ok "git $(git --version | awk '{print $3}')"
elif _apt_bootstrap git; then
    _ok "git $(git --version | awk '{print $3}') (just installed)"
else
    echo -e "${RED}  ✗${NC} git — not found  →  sudo apt install git" >&2
    _preflight_ok=false
fi

# transfer tool (curl or wget — needed by install.sh to fetch binaries)
if command -v curl &>/dev/null; then
    _ok "curl $(curl --version | awk 'NR==1{print $2}')"
elif command -v wget &>/dev/null; then
    _ok "wget $(wget --version 2>&1 | awk 'NR==1{print $3}')"
elif _apt_bootstrap curl; then
    _ok "curl $(curl --version | awk 'NR==1{print $2}') (just installed)"
else
    echo -e "${RED}  ✗${NC} curl/wget — neither found  →  sudo apt install curl" >&2
    _preflight_ok=false
fi

# sudo (soft — not needed when already root)
if [ -n "${NOSUDO:-}" ]; then
    _warn "NOSUDO set — sudo checks skipped (user-local install)"
elif [ "$(id -u)" -eq 0 ]; then
    _ok "running as root (sudo not required)"
elif command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
    _ok "sudo (passwordless)"
elif command -v sudo &>/dev/null; then
    _warn "sudo present but requires a password — you will be prompted when apt runs"
else
    _warn "sudo not found — apt package installs will be skipped"
fi

# OS (soft — scripts are written for Ubuntu/Debian)
if [ -f /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    case "${ID:-}" in
        ubuntu) _ok "OS: Ubuntu ${VERSION_ID:-}" ;;
        debian) _warn "OS: Debian ${VERSION_ID:-} — supported but not tested" ;;
        *)      _warn "OS: ${PRETTY_NAME:-unknown} — scripts are written for Ubuntu; proceed with caution" ;;
    esac
else
    _warn "OS: unknown — /etc/os-release not found"
fi

# disk space (2 GB required in $HOME)
_avail_mb=$(df -m "$HOME" 2>/dev/null | awk 'NR==2{print $4}')
if [ -n "$_avail_mb" ]; then
    if [ "$_avail_mb" -ge 2048 ]; then
        _ok "Disk: ${_avail_mb} MB free in \$HOME"
    else
        _warn "Disk: only ${_avail_mb} MB free in \$HOME (2048 MB recommended)"
    fi
fi

# network
if command -v curl &>/dev/null; then
    _net_ok=$(curl -sSf --max-time 5 https://github.com &>/dev/null && echo yes || echo no)
elif command -v wget &>/dev/null; then
    _net_ok=$(wget -q --spider --timeout=5 https://github.com &>/dev/null && echo yes || echo no)
else
    _net_ok=no
fi
if [ "$_net_ok" = "yes" ]; then
    _ok "Network: github.com reachable"
else
    _warn "Network: github.com unreachable — install may fail on download steps"
fi

echo ""
if ! $_preflight_ok; then
    _die "Fix the errors above and re-run."
fi

# ── Clone or update ────────────────────────────────────────────────────────────
if [ -d "$DEST/.git" ]; then
    _info "Dotfiles found at $DEST — pulling latest…"

    # Stale lock from a previously interrupted git operation
    if [ -f "$DEST/.git/index.lock" ]; then
        _die "Git index is locked at $DEST/.git/index.lock\n  If no git process is running: rm '$DEST/.git/index.lock'\n  Then: bash '$DEST/install.sh' ${PROFILE:-workstation}"
    fi

    # Unfinished merge or rebase
    if [ -f "$DEST/.git/MERGE_HEAD" ] || [ -d "$DEST/.git/rebase-merge" ] || [ -d "$DEST/.git/rebase-apply" ]; then
        _die "Repo at $DEST is in an unfinished merge/rebase state.\n  Resolve it first: git -C '$DEST' status\n  Then: bash '$DEST/install.sh' ${PROFILE:-workstation}"
    fi

    # Local modifications would be overwritten by pull
    if ! git -C "$DEST" diff --quiet HEAD 2>/dev/null; then
        _warn "Local modifications detected — cannot pull cleanly:"
        git -C "$DEST" diff --name-only HEAD 2>/dev/null | while IFS= read -r f; do _warn "  $f"; done
        _warn "Resolve manually, then run install.sh directly (get.sh is gone after curl-pipe):"
        _warn "  git -C '$DEST' stash"
        _warn "  git -C '$DEST' pull"
        _warn "  git -C '$DEST' stash pop"
        _warn "  # WARNING: if stash pop has conflicts, ~/.zshrc may break."
        _warn "  # If that happens: exec bash (use bash until resolved)"
        _warn "  # Accept upstream: git -C '$DEST' checkout -- <file>"
        _warn "  # Then: git -C '$DEST' stash drop"
        _warn "  bash '$DEST/install.sh' ${PROFILE:-workstation}"
        _die "Aborting — resolve local changes first."
    fi

    # Local commits ahead of upstream (clean tree but diverged)
    if git -C "$DEST" rev-parse '@{u}' &>/dev/null; then
        _ahead=$(git -C "$DEST" rev-list '@{u}..HEAD' --count 2>/dev/null || echo 0)
        if [ "${_ahead:-0}" -gt 0 ]; then
            _warn "Local commits on this clone (${_ahead} ahead of upstream):"
            git -C "$DEST" log '@{u}..HEAD' --oneline >&2
            _die "Resolve manually:\n  git -C '$DEST' fetch\n  git -C '$DEST' reset --hard '@{u}'  # WARNING: discards those commits\n  bash '$DEST/install.sh' ${PROFILE:-workstation}"
        fi
    fi

    # Pull (network failure: warn and continue on existing clone)
    if git -C "$DEST" pull --ff-only 2>&1; then
        _ok "Updated to $(git -C "$DEST" describe --tags --always 2>/dev/null || git -C "$DEST" rev-parse --short HEAD)"
    else
        _warn "git pull failed — continuing with existing clone (proceeding with installed version)."
        _warn "To apply latest changes later: git -C '$DEST' pull && bash '$DEST/install.sh' ${PROFILE:-workstation}"
    fi

elif [ -e "$DEST" ]; then
    _die "$DEST already exists but is not a dotfiles repo.\n  Remove it or set DOTFILES_DIR to a different path:\n  DOTFILES_DIR=~/my-dotfiles bash get.sh ${PROFILE:-}"
else
    _info "Cloning dotfiles to $DEST…"
    git clone "$REPO" "$DEST"
    _ok "Cloned"
fi

# ── Hand off to the real installer ────────────────────────────────────────────
echo ""
if [ -n "$PROFILE" ]; then
    exec bash "$DEST/install.sh" "$PROFILE"
else
    exec bash "$DEST/install.sh"
fi
