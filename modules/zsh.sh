#!/usr/bin/env bash
# Zsh: oh-my-zsh + plugins + powerlevel10k + dotfile config
# Idempotent: skips steps that are already done

install_zsh() {
    local change_shell="${1:-yes}"
    _install_ohmyzsh
    _install_zsh_plugins
    _link_zshrc
    if [ "$change_shell" = "yes" ]; then
        _set_default_shell
    fi
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

_set_default_shell() {
    log_step "Default shell"
    local zsh_path
    zsh_path="$(command -v zsh)"
    if [ "$SHELL" = "$zsh_path" ]; then
        log_ok "zsh is already the default shell"
        return
    fi
    if $CAN_SUDO; then
        # usermod edits /etc/passwd directly — no PAM required (works in containers/CI)
        sudo usermod -s "$zsh_path" "$USER"
        log_ok "Default shell set to zsh (restart your session)"
    elif chsh -s "$zsh_path" 2>/dev/null; then
        log_ok "Default shell set to zsh (restart your session)"
    else
        log_warn "Could not change shell — run: chsh -s $zsh_path"
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
    git clone "${extra_flags[@]}" "$url" "$dest" --quiet
    log_ok "$name installed"
}
