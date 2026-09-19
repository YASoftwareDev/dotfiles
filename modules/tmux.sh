#!/usr/bin/env bash
# Tmux: symlink config files and install plugins
# Idempotent: ln -sf is safe to re-run; git clone skipped if dir exists

# Plugins sourced directly via run-shell in .tmux.conf.local
# (gpakosz framework uses 'if ... source' syntax that TPM's auto-install can't parse)
_TMUX_PLUGINS=(
    "sainnhe/tmux-fzf"
    "tmux-plugins/tmux-cpu"
)

install_tmux() {
    # Do not configure what is not there. Linking tmux config and cloning tmux
    # plugins for an absent tmux is the incoherence that hid the no-sudo gap: a
    # host looked configured while nothing could use it. _install_tmux covers the
    # common cases now, but it still returns empty-handed on a non-x86_64 host, on
    # a download failure, or when the AppImage neither runs nor extracts - so this
    # guard is what makes the outcome honest. Same shape as install_zsh().
    if ! has tmux; then
        log_warn "tmux not found - skipping tmux config and plugins"
        log_warn "  Install tmux, then re-run: bash ${DOTFILES_DIR}/install.sh"
        return 0
    fi
    log_step "tmux config"
    symlink "${DOTFILES_DIR}/tmux/.tmux.conf"       ~/.tmux.conf
    symlink "${DOTFILES_DIR}/tmux/.tmux.conf.local"  ~/.tmux.conf.local
    # Called from the status-row hooks in .tmux.conf.local, so it has to be on
    # PATH under its own name.
    symlink "${DOTFILES_DIR}/tmux/tmux-status-rows"  ~/.local/bin/tmux-status-rows
    log_ok "tmux config linked"
}

_install_tmux_plugins() {
    # Guarded separately, not just via install_tmux: install.sh chains them with
    # `install_tmux && _install_tmux_plugins`, so install_tmux's early return - which
    # must exit 0, or `set -e` would kill the whole install - still lets this run.
    if ! has tmux; then
        log_warn "tmux not found - skipping tmux plugins"
        return 0
    fi
    log_step "tmux plugins"
    local plugin_dir="$HOME/.tmux/plugins"
    mkdir -p "$plugin_dir"

    local all_ok=true
    for repo in "${_TMUX_PLUGINS[@]}"; do
        local name="${repo##*/}"
        local dest="$plugin_dir/$name"
        if [ -d "$dest" ]; then
            log_ok "$name already installed - skipping"
        else
            log_info "$name: installing latest → $dest"
            if git clone --depth 1 "https://github.com/${repo}.git" "$dest" 2>/dev/null; then
                log_ok "$name installed → $dest"
            else
                log_warn "$name: git clone failed - skipping"
                all_ok=false
            fi
        fi
    done

    $all_ok && log_ok "tmux plugins ready" || log_warn "some tmux plugins failed to install"
}
