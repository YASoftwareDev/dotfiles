#!/usr/bin/env bash
# Install cmake using the official pre-built installer from cmake.org.
#
# Usage (run from dotfiles root):
#   ./scripts/install-cmake.sh              # uses default version 4.2.3
#   ./scripts/install-cmake.sh 3.31.7       # install specific version
#
# Installs to /usr/local (with sudo) or $HOME/.local (without sudo).

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/utils.sh"

CMAKE_VERSION="${1:-4.2.3}"

log_step "cmake ${CMAKE_VERSION}"

detect_sudo

# Skip if already at the requested version
if has cmake && cmake --version 2>/dev/null | grep -qF "${CMAKE_VERSION}"; then
    log_ok "cmake ${CMAKE_VERSION} already installed — skipping"
    exit 0
fi

ARCH=$(uname -m)
case "$ARCH" in
    x86_64)  cmake_arch="x86_64"  ;;
    aarch64) cmake_arch="aarch64" ;;
    *)
        die "cmake: unsupported arch $ARCH (only x86_64 and aarch64 supported)"
        ;;
esac

installer_url="https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${cmake_arch}.sh"
installer=$(mktemp /tmp/cmake-install.XXXXXX.sh)
trap 'rm -f "$installer"' EXIT

log_info "Downloading cmake ${CMAKE_VERSION} installer…"
if has curl; then
    curl -sfL "$installer_url" -o "$installer" \
        || die "cmake: download failed (check network and version ${CMAKE_VERSION})"
else
    wget -qO "$installer" "$installer_url" \
        || die "cmake: download failed (check network and version ${CMAKE_VERSION})"
fi
chmod +x "$installer"

if $CAN_SUDO; then
    prefix="/usr/local"
    $SUDO "$installer" --prefix="$prefix" --skip-license --exclude-subdir
else
    prefix="$HOME/.local"
    mkdir -p "$prefix"
    "$installer" --prefix="$prefix" --skip-license --exclude-subdir
fi

log_ok "cmake installed → $prefix ($(cmake --version | head -1))"
