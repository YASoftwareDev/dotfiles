#!/usr/bin/env bash
# Extra tools: fzf, diff-so-fancy, cheat, ripgrep config, ranger config
# Most tools are now installed via apt in base.sh — this handles:
#   • fzf shell integration (key bindings, completion)
#   • diff-so-fancy (not in apt)
#   • cheat (not in standard apt)
#   • Config file symlinks for ripgrep and ranger

install_tools() {
    _install_diff_so_fancy
    _install_cheat
    _link_ripgrep_config
    _link_ranger_config
}

_install_diff_so_fancy() {
    log_step "diff-so-fancy"
    if has diff-so-fancy; then
        log_ok "diff-so-fancy already installed — skipping"
        return
    fi

    mkdir -p ~/.local/bin
    if has curl; then
        curl -sfLo ~/.local/bin/diff-so-fancy \
            https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy
    else
        wget -qO ~/.local/bin/diff-so-fancy \
            https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy
    fi
    chmod +x ~/.local/bin/diff-so-fancy

    # Only set pager if the user hasn't configured one already
    if [ -z "$(git config --global core.pager)" ]; then
        git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
    else
        log_warn "git core.pager already set — skipping. To use diff-so-fancy run:"
        log_warn "  git config --global core.pager \"diff-so-fancy | less --tabs=4 -RFX\""
    fi
    log_ok "diff-so-fancy installed → ~/.local/bin"
}

_install_cheat() {
    log_step "cheat"
    if has cheat; then
        log_ok "cheat already installed — skipping"
        return
    fi

    # Fetch latest release URL for linux-amd64
    local url
    local api="https://api.github.com/repos/cheat/cheat/releases/latest"
    if has curl; then
        url=$(curl -sfL "$api" \
            | grep -o '"browser_download_url": *"[^"]*linux-amd64"' \
            | grep -o 'https://[^"]*')
    elif has wget; then
        url=$(wget -qO- "$api" \
            | grep -o '"browser_download_url": *"[^"]*linux-amd64"' \
            | grep -o 'https://[^"]*')
    fi

    if [ -z "$url" ]; then
        log_warn "Could not fetch cheat release URL — skipping"
        return
    fi

    mkdir -p ~/.local/bin
    if has curl; then
        curl -sfL "$url" | gunzip > ~/.local/bin/cheat
    else
        wget -qO- "$url" | gunzip > ~/.local/bin/cheat
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
