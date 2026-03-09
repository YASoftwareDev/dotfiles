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
        ripgrep fd-find tig \
        fzf parallel shellcheck \
        zoxide

    # fd is installed as 'fdfind' on Debian/Ubuntu — add a shim if fd is missing
    if ! has fd && has fdfind; then
        mkdir -p ~/.local/bin
        ln -sf "$(command -v fdfind)" ~/.local/bin/fd
        log_ok "Created fd → fdfind shim in ~/.local/bin"
    fi

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
    $SUDO update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

    apt_install \
        git curl wget \
        zsh tmux neovim \
        jq \
        ripgrep fd-find \
        fzf shellcheck \
        zoxide

    if ! has fd && has fdfind; then
        mkdir -p ~/.local/bin
        ln -sf "$(command -v fdfind)" ~/.local/bin/fd
    fi

    log_ok "Base packages installed (docker)"
}
