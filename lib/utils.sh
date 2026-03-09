#!/usr/bin/env bash
# Shared logging and helper utilities for dotfiles install

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "  ${BLUE}→${NC} $*"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
log_warn()  { echo -e "  ${YELLOW}!${NC} $*" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $*" >&2; }
log_step()  { echo -e "\n${BOLD}── $* ──${NC}"; }
die()       { log_error "$*"; exit 1; }

# Check if a command exists
has() { command -v "$1" &>/dev/null; }

# Run apt-get quietly with noninteractive frontend
apt_install() {
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -yq "$@"
}

# Check if we can use sudo (sets globals SUDO and CAN_SUDO)
detect_sudo() {
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
        CAN_SUDO=true
    elif sudo -v 2>/dev/null; then
        SUDO="sudo"
        CAN_SUDO=true
    else
        SUDO=""
        CAN_SUDO=false
        log_warn "No sudo access — skipping system package installation."
    fi
    export SUDO CAN_SUDO
}

# Safe symlink: creates parent dir and force-overwrites existing link
symlink() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
}
