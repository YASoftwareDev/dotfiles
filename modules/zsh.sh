#!/usr/bin/env bash
# Zsh: oh-my-zsh + plugins + powerlevel10k + dotfile config
# Idempotent: skips steps that are already done

install_zsh() {
    local change_shell="${1:-yes}"
    if ! has zsh; then
        log_warn "zsh not found — skipping oh-my-zsh, plugins, and zshrc setup"
        log_warn "  Install zsh via your package manager, then re-run: bash ~/.dotfiles/install.sh"
        return 0
    fi
    _install_ohmyzsh
    _install_zsh_plugins
    _link_zshrc
    if [ "$change_shell" = "yes" ]; then
        _set_default_shell
    fi
    _patch_bashrc_for_docker
}

_patch_bashrc_for_docker() {
    # In Docker, `docker exec` starts bash directly regardless of /etc/passwd.
    # Patch ~/.bashrc so interactive bash sessions auto-switch to zsh.
    [ -f /.dockerenv ] || return 0
    grep -q 'exec zsh' "${HOME}/.bashrc" 2>/dev/null && return 0
    printf '\n# Switch to zsh for interactive sessions (added by dotfiles)\n' >> "${HOME}/.bashrc"
    printf '[ -z "$ZSH_VERSION" ] && [ -t 0 ] && exec zsh\n' >> "${HOME}/.bashrc"
    log_ok "~/.bashrc patched: interactive bash sessions will auto-switch to zsh"
}

_install_ohmyzsh() {
    log_step "oh-my-zsh"
    if [ -d ~/.oh-my-zsh ]; then
        log_ok "oh-my-zsh already installed — skipping"
        return
    fi

    local installer
    if has curl; then
        installer="curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    else
        installer="wget -qO- https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
    fi
    log_info "oh-my-zsh: installing latest → ~/.oh-my-zsh"
    RUNZSH=no CHSH=no sh -c "$($installer)" 2>/dev/null
    log_ok "oh-my-zsh installed"
}

_install_zsh_plugins() {
    local custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

    log_step "zsh plugins"
    _git_clone_if_missing \
        "https://github.com/zsh-users/zsh-autosuggestions" \
        "$custom/plugins/zsh-autosuggestions" \
        "zsh-autosuggestions"

    _git_clone_if_missing \
        "https://github.com/zdharma-continuum/fast-syntax-highlighting" \
        "$custom/plugins/fast-syntax-highlighting" \
        "fast-syntax-highlighting"

    _git_clone_if_missing \
        "https://github.com/Aloxaf/fzf-tab" \
        "$custom/plugins/fzf-tab" \
        "fzf-tab"

    _git_clone_if_missing \
        "https://github.com/romkatv/powerlevel10k" \
        "$custom/themes/powerlevel10k" \
        "powerlevel10k" \
        "--depth=1"
}

_link_zshrc() {
    log_step "zsh config"
    symlink "${DOTFILES_DIR}/zsh/.zshrc" ~/.zshrc
    log_ok "~/.zshrc → dotfiles/zsh/.zshrc"
}

# Set by _set_default_shell; read by install.sh's "next steps" section.
_SHELL_IS_ZSH=false

_set_default_shell() {
    log_step "Default shell"
    local zsh_path
    zsh_path="$(command -v zsh)"
    if [ -z "$zsh_path" ]; then
        log_warn "zsh not found in PATH — cannot set default shell"
        return 0
    fi
    if [ "${SHELL:-}" = "$zsh_path" ]; then
        log_ok "zsh is already the default shell"
        _SHELL_IS_ZSH=true
        return
    fi
    if $CAN_SUDO; then
        # usermod edits /etc/passwd directly — no PAM required (works in containers/CI)
        if ! sudo -n true 2>/dev/null; then
            log_warn "sudo credential cache may have expired — you may be prompted"
        fi
        [ -n "${SUDO:-}" ] && sudo -v 2>/dev/null || true
        $SUDO usermod -s "$zsh_path" "$(id -un)"
        log_ok "Default shell set to zsh (restart your session)"
        _SHELL_IS_ZSH=true
    elif chsh -s "$zsh_path" 2>/dev/null; then
        log_ok "Default shell set to zsh (restart your session)"
        _SHELL_IS_ZSH=true
    else
        log_warn "Could not change shell — run: chsh -s $zsh_path"
        _SHELL_IS_ZSH=false
    fi
}

_git_clone_if_missing() {
    local url="$1" dest="$2" name="$3"
    local -a extra_flags=()
    [ -n "${4:-}" ] && extra_flags=("$4")
    if [ -d "$dest" ]; then
        log_ok "$name already installed — skipping"
        return
    fi
    log_info "$name: installing latest → $dest"
    git clone "${extra_flags[@]}" "$url" "$dest" --quiet
    log_ok "$name installed → $dest"
}
