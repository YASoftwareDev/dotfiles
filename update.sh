#!/usr/bin/env bash
# Update all managed tools and plugins
# Safe to run periodically — updates in-place, no reinstall needed

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DOTFILES_DIR}/lib/utils.sh"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ── System packages ───────────────────────────────────────────────────────────
detect_sudo
if $CAN_SUDO; then
    log_step "System packages (apt)"
    $SUDO apt-get -yq update
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get -yq upgrade
    log_ok "System packages updated"
else
    log_warn "No sudo — skipping apt upgrade"
fi

# ── oh-my-zsh ─────────────────────────────────────────────────────────────────
log_step "oh-my-zsh"
if [ -d ~/.oh-my-zsh ]; then
    zsh -c 'source ~/.oh-my-zsh/oh-my-zsh.sh; omz update --unattended' 2>/dev/null \
        || git -C ~/.oh-my-zsh pull --quiet
    log_ok "oh-my-zsh updated"
else
    log_warn "oh-my-zsh not installed — skipping"
fi

# ── zsh plugins ───────────────────────────────────────────────────────────────
_update_plugin() {
    local name="$1" path="$2"
    if [ -d "$path" ]; then
        git -C "$path" pull --quiet --ff-only
        log_ok "$name updated"
    else
        log_warn "$name not found at $path — skipping"
    fi
}

log_step "zsh plugins"
_update_plugin "powerlevel10k"           "$ZSH_CUSTOM/themes/powerlevel10k"
_update_plugin "zsh-autosuggestions"     "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
_update_plugin "fast-syntax-highlighting" "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
_update_plugin "fzf-tab"                 "$ZSH_CUSTOM/plugins/fzf-tab"

# ── diff-so-fancy ─────────────────────────────────────────────────────────────
log_step "diff-so-fancy"
if [ -f ~/.local/bin/diff-so-fancy ]; then
    if has curl; then
        curl -sfLo ~/.local/bin/diff-so-fancy \
            https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy
    else
        wget -qO ~/.local/bin/diff-so-fancy \
            https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy
    fi
    chmod +x ~/.local/bin/diff-so-fancy
    log_ok "diff-so-fancy updated"
else
    log_warn "diff-so-fancy not installed — run install.sh workstation first"
fi

# ── cheat ─────────────────────────────────────────────────────────────────────
log_step "cheat"
if [ -f ~/.local/bin/cheat ]; then
    local api="https://api.github.com/repos/cheat/cheat/releases/latest"
    local url=""
    if has curl; then
        url=$(curl -sfL "$api" \
            | grep -o '"browser_download_url": *"[^"]*linux-amd64"' \
            | grep -o 'https://[^"]*')
    elif has wget; then
        url=$(wget -qO- "$api" \
            | grep -o '"browser_download_url": *"[^"]*linux-amd64"' \
            | grep -o 'https://[^"]*')
    fi
    if [ -n "$url" ]; then
        if has curl; then
            curl -sfL "$url" | gunzip > ~/.local/bin/cheat
        else
            wget -qO- "$url" | gunzip > ~/.local/bin/cheat
        fi
        chmod +x ~/.local/bin/cheat
        log_ok "cheat updated"
    else
        log_warn "Could not fetch cheat release URL — skipping"
    fi
else
    log_warn "cheat not installed — run install.sh workstation first"
fi

echo ""
log_ok "Update complete — restart your shell to apply changes"
echo ""
