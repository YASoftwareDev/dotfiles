#!/usr/bin/env bash
# Extra tools: uv, ruff, cheat, ripgrep config, ranger config
# Most tools are now installed via apt in base.sh — this handles:
#   • uv (Python package manager / venv tool, not in apt)
#   • ruff (Python linter/formatter, installed via uv tool)
#   • cheat (not in standard apt)
#   • Config file symlinks for ripgrep and ranger

install_tools() {
    _install_uv
    _install_ruff
    _install_cheat
    _link_ripgrep_config
    _link_ranger_config
}

_install_ruff() {
    log_step "ruff"
    if has ruff; then
        log_ok "ruff already installed — skipping"
        return
    fi
    local uv_bin
    uv_bin=$(command -v uv 2>/dev/null || echo ~/.local/bin/uv)
    if [ ! -x "$uv_bin" ]; then
        log_warn "uv not found — skipping ruff install"
        return
    fi
    "$uv_bin" tool install ruff
    log_ok "ruff installed ($(command -v ruff >/dev/null 2>&1 && ruff --version 2>/dev/null || echo "run: source ~/.zshrc to activate"))"
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

    # uv uses stable asset names (no version in filename) — use direct URL, no API needed
    local url="https://github.com/astral-sh/uv/releases/latest/download/uv-${uv_arch}.tar.gz"

    mkdir -p ~/.local/bin
    local tmp
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN
    local download_ok=true
    if has curl; then
        curl -sfL "$url" | tar -xz -C "$tmp" || download_ok=false
    else
        wget -qO- "$url" | tar -xz -C "$tmp" || download_ok=false
    fi
    if ! $download_ok; then
        log_warn "uv: download or extraction failed — skipping (network issue?)"
        return
    fi
    # Tarball contains uv and uvx binaries
    for bin in uv uvx; do
        local found
        found=$(find "$tmp" -name "$bin" -type f | head -1)
        [ -n "$found" ] && mv "$found" ~/.local/bin/"$bin" && chmod +x ~/.local/bin/"$bin"
    done

    if [ ! -f ~/.local/bin/uv ]; then
        log_warn "uv: binary not found in archive — archive structure may have changed"
        return
    fi
    log_ok "uv installed → ~/.local/bin ($(~/.local/bin/uv --version 2>/dev/null))"
}


_install_cheat() {
    log_step "cheat"
    if has cheat; then
        log_ok "cheat already installed — skipping"
        return
    fi

    local arch
    arch=$(uname -m)
    local cheat_arch
    case "$arch" in
        x86_64)  cheat_arch="amd64" ;;
        aarch64) cheat_arch="arm64" ;;
        *)
            log_warn "cheat: unsupported arch $arch — skipping"
            return
            ;;
    esac

    # cheat uses stable asset names (no version in filename) — use direct URL, no API needed
    local url="https://github.com/cheat/cheat/releases/latest/download/cheat-linux-${cheat_arch}.gz"

    mkdir -p ~/.local/bin
    local ok=true
    if has curl; then
        curl -sfL "$url" | gunzip > ~/.local/bin/cheat || ok=false
    else
        wget -qO- "$url" | gunzip > ~/.local/bin/cheat || ok=false
    fi
    if ! $ok; then
        log_warn "cheat: download or decompression failed — skipping"
        rm -f ~/.local/bin/cheat
        return
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
