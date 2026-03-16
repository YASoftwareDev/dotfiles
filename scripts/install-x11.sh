#!/usr/bin/env bash
# X11 keyboard remapping: Caps Lock = Ctrl (hold) / Escape (tap)
#
# Usage (run from dotfiles root):
#   ./scripts/install-x11.sh
#
# What it does:
#   - Installs xcape (built from source: https://github.com/alols/xcape)
#   - Symlinks ~/.xprofile -> dotfiles/x11/.xprofile
#   - Applies setxkbmap immediately (no relogin needed for that part)
#   - xcape takes effect at next X session login (or run xcape manually)
#
# Intended for Vim/Neovim users who want Caps Lock as dual-function:
#   tap  → Escape
#   hold → Ctrl
#
# Not part of the default workstation install — run manually if you want it.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/utils.sh"

detect_sudo

log_step "xcape"
if has xcape; then
    log_ok "xcape already installed at $(command -v xcape) — skipping build"
else
    if ! $CAN_SUDO; then
        die "xcape requires sudo to install build deps and copy binary to /usr/local/bin"
    fi

    log_info "Installing build dependencies"
    apt_install libxtst-dev libx11-dev pkg-config make gcc

    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT

    log_info "Cloning alols/xcape and building"
    git clone --depth=1 https://github.com/alols/xcape.git "$tmp/xcape"
    make -C "$tmp/xcape"
    $SUDO install -m 755 "$tmp/xcape/xcape" /usr/local/bin/xcape
    log_ok "xcape installed → /usr/local/bin/xcape"
fi

log_step "~/.xprofile"
symlink "${DOTFILES_DIR}/x11/.xprofile" ~/.xprofile
log_ok "~/.xprofile linked"

log_step "Applying keyboard remapping to current session"
setxkbmap -option caps:ctrl_modifier
pkill -x xcape 2>/dev/null || true
xcape -e 'Caps_Lock=Escape'
log_ok "setxkbmap + xcape active (Caps Lock = Ctrl/Escape)"

echo ""
log_ok "Done — remapping is active now and will persist via ~/.xprofile at next login"
echo ""
