#!/usr/bin/env bash
# YA Dotfiles — one-line bootstrap
#
# Usage (pick a flavor):
#
#   workstation (default — full setup, interactive wizard):
#     curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash
#
#   minimal (zsh + tmux + git config only):
#     curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash -s -- minimal
#
#   docker (headless, CI-friendly, no shell change):
#     curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash -s -- docker
#
# Or inspect first, then run:
#   curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh -o get.sh
#   bash get.sh [minimal|workstation|docker]
#

set -euo pipefail

REPO="https://github.com/YASoftwareDev/dotfiles.git"
DEST="${DOTFILES_DIR:-$HOME/.dotfiles}"
PROFILE="${1:-}"

# ── Colour helpers ─────────────────────────────────────────────────────────────
BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
_info()  { echo -e "${BOLD}  →${NC} $*"; }
_ok()    { echo -e "${GREEN}  ✓${NC} $*"; }
_warn()  { echo -e "${YELLOW}  !${NC} $*"; }

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗"
echo -e "║      YA Dotfiles — Bootstrap             ║"
echo -e "╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Require git ────────────────────────────────────────────────────────────────
if ! command -v git &>/dev/null; then
    echo "ERROR: git is required but not found. Install git first." >&2
    exit 1
fi

# ── Clone or update ────────────────────────────────────────────────────────────
if [ -d "$DEST/.git" ]; then
    _info "Dotfiles already cloned at $DEST — pulling latest…"
    git -C "$DEST" pull --quiet --rebase
    _ok "Updated"
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
