#!/usr/bin/env bash
# Base system packages — requires apt (Ubuntu/Debian)
# Idempotent: apt handles "already installed" gracefully

install_base() {
    log_step "Base packages"
    if ! $CAN_SUDO; then
        log_warn "Skipping system packages (no sudo)"
        return
    fi

    $SUDO apt-get -yq update
    apt_install \
        git curl wget \
        zsh tmux neovim \
        ranger jq \
        man-db gnupg \
        python3 python3-venv \
        ripgrep fd-find tig \
        fzf parallel shellcheck \
        zoxide git-delta

    # fd is installed as 'fdfind' on Debian/Ubuntu — add a shim if fd is missing
    if ! has fd && has fdfind; then
        mkdir -p ~/.local/bin
        ln -sf "$(command -v fdfind)" ~/.local/bin/fd
        log_ok "Created fd → fdfind shim in ~/.local/bin"
    fi

    _install_fzf_shell_integration

    log_ok "Base packages installed"
}

install_base_docker() {
    log_step "Base packages (docker mode)"
    if ! $CAN_SUDO; then
        log_warn "Skipping system packages (no sudo)"
        return
    fi

    $SUDO apt-get -yq update
    apt_install locales
    $SUDO locale-gen en_US.UTF-8
    $SUDO update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

    apt_install \
        git curl wget \
        zsh tmux neovim \
        jq \
        ripgrep fd-find \
        fzf shellcheck \
        zoxide git-delta

    if ! has fd && has fdfind; then
        mkdir -p ~/.local/bin
        ln -sf "$(command -v fdfind)" ~/.local/bin/fd
    fi

    _install_fzf_shell_integration

    log_ok "Base packages installed (docker)"
}

# fzf apt packages on Ubuntu 22.04+ no longer ship zsh shell integration.
# Download the canonical files from upstream so the oh-my-zsh fzf plugin
# can source them from the expected Debian path.
_install_fzf_shell_integration() {
    local dest="/usr/share/doc/fzf/examples"

    # Both files must exist; a partial state re-triggers the download
    [ -f "$dest/key-bindings.zsh" ] && [ -f "$dest/completion.zsh" ] && return
    has fzf || return

    # Pin to the installed fzf version so shell integration syntax matches the binary.
    # `fzf --version` outputs e.g. "0.44.1 (brew)" or "0.29.0" — extract the semver part.
    local ver
    ver=$(fzf --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
    # Normalise two-part versions (0.29 → 0.29.0) so the GitHub tag exists
    case "$ver" in
        [0-9]*.[0-9]*.[0-9]*) : ;;          # already three-part
        [0-9]*.[0-9]*)        ver="${ver}.0" ;;
        *)                    ver="" ;;     # couldn't parse — fall back to master
    esac
    local tag="${ver:+v$ver}"
    local base="https://raw.githubusercontent.com/junegunn/fzf/${tag:-master}/shell"

    log_step "fzf shell integration (${tag:-master})"
    $SUDO mkdir -p "$dest"

    local ok=true
    if has curl; then
        $SUDO curl -sfLo "$dest/key-bindings.zsh" "$base/key-bindings.zsh" || ok=false
        $SUDO curl -sfLo "$dest/completion.zsh"   "$base/completion.zsh"   || ok=false
    else
        $SUDO wget -qO "$dest/key-bindings.zsh" "$base/key-bindings.zsh" || ok=false
        $SUDO wget -qO "$dest/completion.zsh"   "$base/completion.zsh"   || ok=false
    fi

    if $ok; then
        log_ok "fzf shell integration installed"
    else
        log_warn "fzf shell integration download failed — fzf key bindings won't work in zsh"
    fi
}
