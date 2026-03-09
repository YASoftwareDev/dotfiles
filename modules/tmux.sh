#!/usr/bin/env bash
# Tmux: symlink config files
# Idempotent: ln -sf is safe to re-run

install_tmux() {
    log_step "tmux config"
    symlink "${DOTFILES_DIR}/tmux/.tmux.conf"       ~/.tmux.conf
    symlink "${DOTFILES_DIR}/tmux/.tmux.conf.local"  ~/.tmux.conf.local
    log_ok "tmux config linked"
}
