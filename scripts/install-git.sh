#!/usr/bin/env bash
# Build and install git from source.
#
# Usage (run from dotfiles root):
#   ./scripts/install-git.sh              # uses default version 2.53.0
#   ./scripts/install-git.sh 2.48.1       # install specific version
#
# Installs to /usr/local (with sudo) or $HOME/.local (without sudo).

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/utils.sh"

GIT_VERSION="${1:-2.53.0}"

log_step "git from source (${GIT_VERSION})"

detect_sudo

# Skip if already at the requested version
if has git && git --version 2>/dev/null | grep -qF " ${GIT_VERSION}"; then
    log_ok "git ${GIT_VERSION} already installed — skipping"
    exit 0
fi

# Install build dependencies
if $CAN_SUDO; then
    log_step "Build dependencies"
    $SUDO apt-get -yq update
    apt_install \
        libssl-dev libcurl4-gnutls-dev libexpat1-dev \
        make gcc gettext
else
    log_warn "No sudo — ensure build deps are installed:"
    log_warn "  libssl-dev libcurl4-gnutls-dev libexpat1-dev make gcc gettext"
fi

# Download
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

url="https://www.kernel.org/pub/software/scm/git/git-${GIT_VERSION}.tar.gz"
log_info "Downloading git ${GIT_VERSION}…"
if has curl; then
    curl -sfL "$url" | tar -xz -C "$tmp" \
        || die "git: download/extraction failed (check network and version ${GIT_VERSION})"
else
    wget -qO- "$url" | tar -xz -C "$tmp" \
        || die "git: download/extraction failed (check network and version ${GIT_VERSION})"
fi

src="${tmp}/git-${GIT_VERSION}"
if [ ! -d "$src" ]; then
    die "Unexpected archive layout — expected ${src}"
fi

# Install prefix
if $CAN_SUDO; then
    prefix="/usr/local"
else
    prefix="$HOME/.local"
    mkdir -p "$prefix"
fi

# Build
log_step "Building git ${GIT_VERSION}"
pushd "$src" > /dev/null
make -s prefix="${prefix}" all
if $CAN_SUDO; then
    $SUDO make -s prefix="${prefix}" install
else
    make -s prefix="${prefix}" install
fi
popd > /dev/null

log_ok "git installed → ${prefix} ($(git --version))"
