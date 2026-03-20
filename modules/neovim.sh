#!/usr/bin/env bash
# Neovim: install latest stable release from GitHub (prebuilt tarball).
# Falls back to apt if GitHub is unreachable or arch is unsupported.
# Idempotent: skips install when the installed version already matches latest.

# Probe ~/.local/bin/nvim and ~/bin/nvim for older copies that would shadow
# CANONICAL (/usr/local/bin/nvim). Warns with a fix command for each found.
# Uses direct path probes — not `command -v` — so install-time bash PATH
# differences don't mask the shadow.
_nvim_warn_shadows() {
    local canonical="$1"
    local _cv _sv _shadow
    _cv=$(_cmd_version "$canonical" --version) || _cv=""
    [ -z "$_cv" ] && return 0  # canonical unreadable — nothing useful to compare
    for _shadow in "$HOME/.local/bin/nvim" "$HOME/bin/nvim"; do
        [ -e "$_shadow" ] || continue
        _sv=$(_cmd_version "$_shadow" --version) || _sv=""
        if _ver_older_than "$_sv" "$_cv"; then
            log_warn "neovim: $_shadow ($_sv) will shadow $canonical ($_cv)"
            log_warn "  Fix: rm $_shadow"
        fi
    done
}

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

    # Install prefix: /usr/local with sudo, ~/.local without (needed for disclosure below)
    local prefix
    if $CAN_SUDO; then prefix="/usr/local"; else prefix="$HOME/.local"; fi

    # Skip if already at latest version
    if has nvim; then
        local current
        current=$(nvim --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ "$current" = "$latest" ]; then
            log_ok "neovim $latest_tag already installed — skipping"
            # Shadow check still needed: `nvim` above may have resolved to a
            # user-local copy (e.g. ~/.local/bin/nvim) that shadows an existing
            # /usr/local/bin/nvim at the same version.
            if $CAN_SUDO; then _nvim_warn_shadows /usr/local/bin/nvim; fi
            return
        fi
        log_info "neovim: upgrading $current → $latest (installing to $prefix)"
        log_info "neovim: GitHub binary will overwrite any apt-installed version"
    else
        log_info "neovim: installing $latest_tag → $prefix"
    fi

    if ! $CAN_SUDO; then mkdir -p "$prefix"; fi

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
        # Refresh credential cache right before use — the download above may have
        # taken long enough for the 15-minute sudo cache to expire.
        if ! sudo -n true 2>/dev/null; then
            log_warn "sudo credential cache may have expired — you may be prompted"
        fi
        [ -n "${SUDO:-}" ] && sudo -v 2>/dev/null || true
        $SUDO cp -r "$extracted"/. "$prefix/"
    else
        cp -r "$extracted"/. "$prefix/"
    fi

    # Use the full path so the version shown is always the binary we just
    # installed, not whatever `nvim` resolves to in the install-time bash PATH.
    log_ok "neovim installed → $prefix ($($prefix/bin/nvim --version 2>/dev/null | head -1))"
    if $CAN_SUDO; then _nvim_warn_shadows /usr/local/bin/nvim; fi
}

_neovim_apt() {
    if ! $CAN_SUDO; then
        log_warn "neovim: no sudo — cannot install via apt"
        return
    fi
    apt_install neovim
    log_ok "neovim installed via apt ($(nvim --version 2>/dev/null | head -1))"
}
