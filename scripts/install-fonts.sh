#!/usr/bin/env bash
# Install MesloLGS NF — the Nerd Font variant used by this dotfiles setup.
#
# Usage:
#   ./scripts/install-fonts.sh
#
# Downloads the 4 MesloLGS NF variants patched by romkatv (powerlevel10k author)
# and installs them to ~/.local/share/fonts/ (no sudo required).
#
# NOTE: install this on the machine running your terminal (local workstation),
# not on a remote server you SSH into. Terminals render fonts locally.
#
# After install:
#   Set your terminal font to "MesloLGS NF" at 12–13pt.
#   See README.md "Font" section for per-terminal instructions.

set -euo pipefail

FONT_DIR="$HOME/.local/share/fonts/MesloLGS-NF"
BASE_URL="https://github.com/romkatv/powerlevel10k-media/raw/master"

declare -a FONTS=(
    "MesloLGS NF Regular.ttf"
    "MesloLGS NF Bold.ttf"
    "MesloLGS NF Italic.ttf"
    "MesloLGS NF Bold Italic.ttf"
)

# ── Prerequisites ─────────────────────────────────────────────────────────────
if ! command -v fc-cache &>/dev/null; then
    echo "  fontconfig not found — installing…"
    if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
        sudo apt-get -yq install fontconfig
    elif [ "$(id -u)" -eq 0 ]; then
        apt-get -yq install fontconfig
    else
        echo "Error: fontconfig (fc-cache) is required but not installed." >&2
        echo "  Run: sudo apt-get install -y fontconfig" >&2
        exit 1
    fi
fi

# ── Download ──────────────────────────────────────────────────────────────────
echo ""
echo "Installing MesloLGS NF fonts → $FONT_DIR"
echo ""

mkdir -p "$FONT_DIR"

_download() {
    local url="$1" dest="$2"
    local tmp="${dest}.tmp"

    if command -v curl &>/dev/null; then
        http_code=$(curl -fsSL -w "%{http_code}" "$url" -o "$tmp" 2>/dev/null) || http_code="000"
    else
        wget -q "$url" -O "$tmp" 2>/dev/null && http_code="200" || http_code="000"
    fi

    if [ "$http_code" != "200" ]; then
        rm -f "$tmp"
        echo "  ✗ download failed (HTTP $http_code): $url" >&2
        return 1
    fi

    # Sanity check: a valid TTF starts with \x00\x01\x00\x00 or 'OTTO' or 'true'
    local size
    size=$(wc -c < "$tmp")
    if [ "$size" -lt 1000 ]; then
        rm -f "$tmp"
        echo "  ✗ download produced a suspiciously small file ($size bytes) — possible 404 page" >&2
        return 1
    fi

    mv "$tmp" "$dest"
}

all_ok=true
for font in "${FONTS[@]}"; do
    dest="$FONT_DIR/$font"
    if [ -f "$dest" ]; then
        echo "  ✓ already present: $font"
        continue
    fi
    encoded="${font// /%20}"
    echo "  ↓ $font"
    if ! _download "${BASE_URL}/${encoded}" "$dest"; then
        all_ok=false
    fi
done

if ! $all_ok; then
    echo "" >&2
    echo "  Some fonts failed to download. Check your network connection and retry." >&2
    exit 1
fi

# ── Font cache ────────────────────────────────────────────────────────────────
echo ""
echo "  Refreshing font cache…"
fc-cache -f "$FONT_DIR"

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
if fc-list | grep -qi "MesloLGS"; then
    echo "  ✓ MesloLGS NF installed and indexed by fontconfig"
else
    echo "  ⚠ fonts installed but not found by fc-list — try: fc-cache -f ~/.local/share/fonts" >&2
fi

echo ""
echo "  Next: set your terminal font to 'MesloLGS NF' (12–13pt)."
echo "  See README.md for per-terminal setup instructions."
echo ""
