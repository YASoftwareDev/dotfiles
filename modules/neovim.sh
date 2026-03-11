#!/usr/bin/env bash
# Neovim: install latest stable release from GitHub (prebuilt tarball).
# Falls back to apt if GitHub is unreachable or arch is unsupported.
# Idempotent: skips install when the installed version already matches latest.

# Link nvim config from dotfiles repo
link_nvim_config() {
    log_step "nvim config"
    local src="${DOTFILES_DIR}/nvim/.config/nvim"
    if [ ! -d "$src" ]; then
        log_warn "nvim config not found at $src — skipping"
        return
    fi
    local dst="$HOME/.config/nvim"
    # If dst is a real directory (not a symlink), ln -sf would create a link
    # *inside* it rather than replacing it — warn and bail instead.
    if [ -d "$dst" ] && [ ! -L "$dst" ]; then
        log_warn "~/.config/nvim is a real directory — skipping symlink"
        log_warn "  To link: mv ~/.config/nvim ~/.config/nvim.bak && ln -s $src $dst"
        return
    fi
    symlink "$src" "$dst"
    log_ok "~/.config/nvim → dotfiles/nvim/.config/nvim"
}

install_neovim() {
    log_step "neovim (GitHub releases)"
    # Fetches the API response once and extracts both download URL and tag from
    # it — avoids the two HTTP round-trips that separate _gh_latest_release +
    # _gh_latest_tag calls would require.

    local arch
    arch=$(uname -m)
    local nvim_arch
    case "$arch" in
        x86_64)  nvim_arch="linux-x86_64" ;;
        aarch64) nvim_arch="linux-arm64"  ;;
        *)
            log_warn "neovim: unsupported arch $arch — falling back to apt"
            _neovim_apt
            return
            ;;
    esac

    local api="https://api.github.com/repos/neovim/neovim/releases/latest"
    local raw
    if has curl; then
        raw=$(curl -sfL "$api") || raw=""
    else
        raw=$(wget -qO- "$api") || raw=""
    fi

    local url
    url=$(printf '%s\n' "$raw" \
        | grep -o '"browser_download_url": *"[^"]*nvim-'"${nvim_arch}"'\.tar\.gz"' \
        | grep -o 'https://[^"]*' \
        | head -1)

    if [ -z "$url" ]; then
        log_warn "neovim: could not fetch release URL — falling back to apt"
        _neovim_apt
        return
    fi

    local latest_tag
    latest_tag=$(printf '%s\n' "$raw" \
        | grep -o '"tag_name": *"[^"]*"' \
        | grep -o 'v[0-9][^"]*' \
        | head -1)
    local latest="${latest_tag#v}"

    # Skip if already at latest version
    if has nvim; then
        local current
        current=$(nvim --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ "$current" = "$latest" ]; then
            log_ok "neovim $latest_tag already installed — skipping"
            return
        fi
        log_info "neovim: upgrading $current → $latest"
    else
        log_info "neovim: installing $latest_tag"
    fi

    # Install prefix: /usr/local with sudo, ~/.local without
    local prefix
    if $CAN_SUDO; then
        prefix="/usr/local"
    else
        prefix="$HOME/.local"
        mkdir -p "$prefix"
    fi

    local tmp
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    if has curl; then
        curl -sfL "$url" | tar -xz -C "$tmp"
    else
        wget -qO- "$url" | tar -xz -C "$tmp"
    fi

    # Tarball extracts to nvim-linux-x86_64/ or nvim-linux-arm64/
    local extracted
    extracted=$(find "$tmp" -maxdepth 1 -type d -name 'nvim-*' | head -1)
    if [ -z "$extracted" ]; then
        log_warn "neovim: unexpected archive layout — skipping"
        return
    fi

    if $CAN_SUDO; then
        $SUDO cp -r "$extracted"/. "$prefix/"
    else
        cp -r "$extracted"/. "$prefix/"
    fi

    log_ok "neovim installed → $prefix ($(nvim --version 2>/dev/null | head -1))"
}

_neovim_apt() {
    if ! $CAN_SUDO; then
        log_warn "neovim: no sudo — cannot install via apt"
        return
    fi
    apt_install neovim
    log_ok "neovim installed via apt ($(nvim --version 2>/dev/null | head -1))"
}
