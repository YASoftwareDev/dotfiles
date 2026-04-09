#!/usr/bin/env bash
# Build and install the latest stable neovim from source.
# Required on systems where glibc < 2.32 (e.g. Ubuntu 20.04) prevents
# running the prebuilt GitHub release binaries.
#
# Usage: bash scripts/install-neovim-src.sh
#        NEOVIM_TAG=v0.12.1 bash scripts/install-neovim-src.sh       # pin version
#        NEOVIM_PREFIX=~/.local bash scripts/install-neovim-src.sh   # nosudo install
set -euo pipefail

# ── Preflight ─────────────────────────────────────────────────────────────────
if ! sudo -n true 2>/dev/null && ! sudo -v 2>/dev/null; then
    echo "ERROR: sudo is required to install build deps and copy files to /usr/local" >&2
    exit 1
fi
echo "Note: this build downloads ~200 MB of dependencies and takes 5–15 minutes."

PREFIX="${NEOVIM_PREFIX:-/usr/local}"

# ── Build dependencies ────────────────────────────────────────────────────────
echo "── Installing build dependencies ──"
sudo apt-get install -y \
    git ninja-build gettext cmake unzip curl build-essential

# ── Resolve tag ──────────────────────────────────────────────────────────────
if [ -z "${NEOVIM_TAG:-}" ]; then
    NEOVIM_TAG=$(curl -sfL \
        https://api.github.com/repos/neovim/neovim/releases/latest \
        | grep -o '"tag_name": *"[^"]*"' \
        | grep -o 'v[^"]*')
fi
[ -n "$NEOVIM_TAG" ] || { echo "ERROR: could not resolve latest neovim tag" >&2; exit 1; }
echo "── Building neovim $NEOVIM_TAG → $PREFIX ──"

# ── Clone ─────────────────────────────────────────────────────────────────────
TMP=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$TMP'" EXIT

git clone --branch "$NEOVIM_TAG" --depth 1 \
    https://github.com/neovim/neovim.git "$TMP/neovim"

cd "$TMP/neovim"

# ── Build ─────────────────────────────────────────────────────────────────────
cmake -B build \
    -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$PREFIX"

cmake --build build -j"$(nproc)"

# ── Install ───────────────────────────────────────────────────────────────────
sudo cmake --install build

VER=$("$PREFIX/bin/nvim" --version 2>/dev/null | head -1) || VER="(unknown)"
echo "✓ $VER installed → $PREFIX"
