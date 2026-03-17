#!/usr/bin/env bash
# X11 keyboard remapping: Caps Lock = Ctrl (hold) / Escape (tap)
#
# Usage (run from dotfiles root):
#   ./scripts/install-x11.sh
#
# What it does:
#   - Installs xcape (built from source: https://github.com/alols/xcape)
#   - Symlinks ~/.local/bin/caps-remap   (the remapping script)
#   - Symlinks ~/.xprofile               (runs caps-remap at X session start)
#   - Symlinks ~/.config/autostart/caps-remap.desktop
#       → required on GNOME: gnome-settings-daemon resets xkb after .xprofile
#         runs, so the autostart entry re-applies the mapping once the session
#         is fully ready.  Safe no-op on non-GNOME desktops.
#   - Applies the remapping to the current session immediately.
#
# Limitations documented in x11/caps-remap.sh:
#   - X11 only (no effect on Wayland; use xremap or keyd there)
#   - startx/xinit users must also source caps-remap from ~/.xinitrc
#   - Assumes keycode 66 is Caps Lock (standard on almost all keyboards)
#
# Not part of the default workstation install — run manually if you want it.

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/utils.sh"

detect_sudo

# ── xcape ──────────────────────────────────────────────────────────────────
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

# ── symlinks ───────────────────────────────────────────────────────────────
log_step "symlinks"

chmod +x "${DOTFILES_DIR}/x11/caps-remap.sh"
symlink "${DOTFILES_DIR}/x11/caps-remap.sh" ~/.local/bin/caps-remap
log_ok "~/.local/bin/caps-remap linked"

symlink "${DOTFILES_DIR}/x11/.xprofile" ~/.xprofile
log_ok "~/.xprofile linked"

symlink "${DOTFILES_DIR}/x11/.config/autostart/caps-remap.desktop" \
    ~/.config/autostart/caps-remap.desktop
log_ok "~/.config/autostart/caps-remap.desktop linked (GNOME autostart)"

# ── apply to current session ───────────────────────────────────────────────
log_step "Applying remapping to current session"
~/.local/bin/caps-remap
log_ok "caps-remap applied (Caps Lock = Ctrl/Escape)"

echo ""
log_ok "Done — remapping is active now and will persist at next login"
if [ -n "${XDG_CURRENT_DESKTOP:-}" ] && echo "$XDG_CURRENT_DESKTOP" | grep -qi gnome; then
    log_info "GNOME detected: autostart entry will re-apply after gnome-settings-daemon at next login"
fi
echo ""
