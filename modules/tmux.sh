#!/usr/bin/env bash
# Tmux: symlink config files and install plugins
# Idempotent: ln -sf is safe to re-run; git clone skipped if dir exists

# Plugins sourced directly via run-shell in .tmux.conf.local
# (gpakosz framework uses 'if ... source' syntax that TPM's auto-install can't parse)
_TMUX_PLUGINS=(
    "tmux-plugins/tmux-resurrect"
    "tmux-plugins/tmux-continuum"
    "sainnhe/tmux-fzf"
    "tmux-plugins/tmux-cpu"
)

install_tmux() {
    log_step "tmux config"
    symlink "${DOTFILES_DIR}/tmux/.tmux.conf"       ~/.tmux.conf
    symlink "${DOTFILES_DIR}/tmux/.tmux.conf.local"  ~/.tmux.conf.local
    log_ok "tmux config linked"

    _install_tmux_plugins
}

_install_tmux_plugins() {
    log_step "tmux plugins"
    local plugin_dir="$HOME/.tmux/plugins"
    mkdir -p "$plugin_dir"

    local all_ok=true
    for repo in "${_TMUX_PLUGINS[@]}"; do
        local name="${repo##*/}"
        local dest="$plugin_dir/$name"
        if [ -d "$dest" ]; then
            log_ok "$name already installed — skipping"
        else
            if git clone --depth 1 "https://github.com/${repo}.git" "$dest" 2>/dev/null; then
                log_ok "$name installed"
            else
                log_warn "$name: git clone failed — skipping"
                all_ok=false
            fi
        fi
    done

    $all_ok && log_ok "tmux plugins ready" || log_warn "some tmux plugins failed to install"
}
