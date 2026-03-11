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
# Or inspect first, then run (also gives you the interactive wizard):
#   curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh -o get.sh
#   bash get.sh [minimal|workstation|docker]
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

# ── Require curl or wget ───────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
    _die "git is required but not found.\n  Install it first: sudo apt install git"
fi

# ── Clone or update ────────────────────────────────────────────────────────────
if [ -d "$DEST/.git" ]; then
    _info "Dotfiles found at $DEST — pulling latest…"
    if ! git -C "$DEST" pull --quiet --rebase 2>/dev/null; then
        _warn "git pull failed (local changes?). Continuing with existing clone."
    else
        _ok "Updated"
    fi
elif [ -e "$DEST" ]; then
    _die "$DEST already exists but is not a dotfiles repo.\n  Remove it or set DOTFILES_DIR to a different path:\n  DOTFILES_DIR=~/my-dotfiles bash get.sh $PROFILE"
else
    _info "Cloning dotfiles to $DEST…"
    git clone --quiet "$REPO" "$DEST"
    _ok "Cloned"
fi

# ── Hand off to the real installer ────────────────────────────────────────────
echo ""
if [ -n "$PROFILE" ]; then
    exec bash "$DEST/install.sh" "$PROFILE"
else
    exec bash "$DEST/install.sh"
fi
