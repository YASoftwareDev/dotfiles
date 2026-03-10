#!/usr/bin/env bash
# Extra tools: uv, cheat, ripgrep config, ranger config
# Most tools are now installed via apt in base.sh — this handles:
#   • uv (Python package manager / venv tool, not in apt)
#   • cheat (not in standard apt)
#   • Config file symlinks for ripgrep and ranger

install_tools() {
    _install_uv
    _install_cheat
    _link_ripgrep_config
    _link_ranger_config
}

_install_uv() {
    log_step "uv"
    if has uv; then
        log_ok "uv already installed — skipping"
        return
    fi

    local arch
    arch=$(uname -m)
    local uv_arch
    case "$arch" in
        x86_64)  uv_arch="x86_64-unknown-linux-musl"  ;;
        aarch64) uv_arch="aarch64-unknown-linux-musl" ;;
        *)
            log_warn "uv: unsupported arch $arch — skipping"
            return
            ;;
    esac

    local api="https://api.github.com/repos/astral-sh/uv/releases/latest"
    local url
    if has curl; then
        url=$(curl -sfL "$api" \
            | grep -o '"browser_download_url": *"[^"]*uv-'"${uv_arch}"'\.tar\.gz"' \
            | grep -o 'https://[^"]*' | head -1)
    else
        url=$(wget -qO- "$api" \
            | grep -o '"browser_download_url": *"[^"]*uv-'"${uv_arch}"'\.tar\.gz"' \
            | grep -o 'https://[^"]*' | head -1)
    fi

    if [ -z "$url" ]; then
        log_warn "uv: could not fetch release URL — skipping"
        return
    fi

    mkdir -p ~/.local/bin
    local tmp
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN
    if has curl; then
        curl -sfL "$url" | tar -xz -C "$tmp"
    else
        wget -qO- "$url" | tar -xz -C "$tmp"
    fi
    # Tarball contains uv and uvx binaries
    for bin in uv uvx; do
        local found
        found=$(find "$tmp" -name "$bin" -type f | head -1)
        [ -n "$found" ] && mv "$found" ~/.local/bin/"$bin" && chmod +x ~/.local/bin/"$bin"
    done

    if ! has uv; then
        log_warn "uv: binary not found in archive — install may have failed"
        return
    fi
    log_ok "uv installed → ~/.local/bin ($(uv --version 2>/dev/null))"
}


_install_cheat() {
    log_step "cheat"
    if has cheat; then
        log_ok "cheat already installed — skipping"
        return
    fi

    # Fetch latest release URL for linux-amd64
    local url
    local api="https://api.github.com/repos/cheat/cheat/releases/latest"
    if has curl; then
        url=$(curl -sfL "$api" \
            | grep -o '"browser_download_url": *"[^"]*linux-amd64"' \
            | grep -o 'https://[^"]*')
    elif has wget; then
        url=$(wget -qO- "$api" \
            | grep -o '"browser_download_url": *"[^"]*linux-amd64"' \
            | grep -o 'https://[^"]*')
    fi

    if [ -z "$url" ]; then
        log_warn "Could not fetch cheat release URL — skipping"
        return
    fi

    mkdir -p ~/.local/bin
    if has curl; then
        curl -sfL "$url" | gunzip > ~/.local/bin/cheat
    else
        wget -qO- "$url" | gunzip > ~/.local/bin/cheat
    fi
    chmod +x ~/.local/bin/cheat
    log_ok "cheat installed → ~/.local/bin"
}

_link_ripgrep_config() {
    log_step "ripgrep config"
    mkdir -p ~/.config/ripgrep
    symlink "${DOTFILES_DIR}/ripgrep/rc" ~/.config/ripgrep/rc
    log_ok "ripgrep config linked"
}

_link_ranger_config() {
    log_step "ranger config"
    # Symlink individual files, not the whole directory.
    # Symlinking the directory would cause ranger to write runtime state
    # (bookmarks, history, tagged) into the git-tracked dotfiles repo.
    mkdir -p ~/.config/ranger
    for f in rc.conf rifle.conf commands.py commands_full.py scope.sh; do
        [ -f "${DOTFILES_DIR}/ranger/$f" ] && symlink "${DOTFILES_DIR}/ranger/$f" ~/.config/ranger/"$f"
    done
    log_ok "ranger config linked"
}
