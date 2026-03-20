#!/usr/bin/env bash
# YA Dotfiles — main installer
#
# Usage:
#   ./install.sh                        # interactive wizard (recommended for first-timers)
#   ./install.sh minimal                # zsh + tmux + git config only
#   ./install.sh workstation            # everything (default for non-interactive runs)
#   ./install.sh docker                 # headless, CI-friendly, no shell change
#   NOSUDO=1 ./install.sh workstation   # force user-local (~/.local/bin) installs, skip apt
#

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# shellcheck source=lib/utils.sh
source lib/utils.sh

# ── Banner ────────────────────────────────────────────────────────────────────
_banner() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════╗"
    echo -e "║      YA Dotfiles — Environment Setup     ║"
    echo -e "╚══════════════════════════════════════════╝${NC}"
    echo ""
}

# ── Interactive profile wizard ────────────────────────────────────────────────
_wizard() {
    # All display output goes to stderr so the menu is visible when called
    # inside $(...) command substitution to capture only the profile name.
    echo "  What kind of environment are you setting up?" >&2
    echo "" >&2
    echo "    1) minimal      — zsh, tmux, git config            (~5 min)" >&2
    echo "    2) workstation  — everything: editor + all tools   (~15 min)" >&2
    echo "    3) docker       — headless, CI-friendly, no fonts  (~3 min)" >&2
    echo "" >&2
    printf "  Choice [1-3, default 2]: " >&2
    read -r choice
    case "$choice" in
        1) echo "minimal" ;;
        3) echo "docker" ;;
        *) echo "workstation" ;;
    esac
}

# ── Profile runners ───────────────────────────────────────────────────────────
_run_minimal() {
    source modules/base.sh  && install_base
    source modules/zsh.sh   && install_zsh
    source modules/tmux.sh  && install_tmux
    _link_git_config
}

_run_workstation() {
    source modules/base.sh   && install_base
    source modules/zsh.sh    && install_zsh
    source modules/tmux.sh   && install_tmux && _install_tmux_plugins
    source modules/tools.sh  && install_tools
    source modules/neovim.sh && install_neovim && link_nvim_config
    _link_git_config
}

_run_docker() {
    source modules/base.sh  && install_base_docker
    source modules/zsh.sh   && install_zsh no
    source modules/tmux.sh  && install_tmux
    _link_git_config
}

_link_git_config() {
    log_step "git config"
    symlink "${DOTFILES_DIR}/git/.gitconfig"    ~/.gitconfig
    symlink "${DOTFILES_DIR}/git/.gitattributes" ~/.gitattributes
    log_ok "git config linked"
}

# ── Main ──────────────────────────────────────────────────────────────────────
_banner

# Determine profile: arg > wizard (if interactive) > default
PROFILE="${1:-}"
if [ -z "$PROFILE" ] && [ -t 0 ]; then
    PROFILE="$(_wizard)"
elif [ -z "$PROFILE" ]; then
    PROFILE="workstation"
fi

log_info "Profile: ${BOLD}${PROFILE}${NC}"
if [ "$PROFILE" = "workstation" ] && [ -f /.dockerenv ]; then
    log_warn "Docker detected with 'workstation' profile (~15 min, full install)."
    log_warn "For a lighter headless install re-run: bash ~/.dotfiles/install.sh docker"
fi
echo ""

# Preconditions
run_checks

# Run
case "$PROFILE" in
    minimal)     _run_minimal ;;
    workstation) _run_workstation ;;
    docker)      _run_docker ;;
    *) die "Unknown profile: '$PROFILE'. Valid options: minimal | workstation | docker" ;;
esac

echo ""
log_ok "Setup complete!"
echo ""
echo "  Next steps:"
case "$PROFILE" in
    minimal|workstation)
        if ${_SHELL_IS_ZSH:-false}; then
            echo "    • Default shell set to zsh — new terminals will open in zsh automatically"
        else
            echo "    • Default shell change failed — new terminals will still use bash"
            echo "    • To fix permanently: chsh -s $(command -v zsh)  then re-login"
        fi
        echo "    • Activate zsh right now (no re-login needed):  exec zsh"
        echo "    • Once in zsh:  p10k configure   to choose your prompt style"
        echo ""
        echo "  Font (run on your LOCAL machine, not here if this is a remote/server):"
        echo "    • ./scripts/install-fonts.sh   — installs MesloLGS NF (required for icons)"
        echo "    • Then set terminal font to 'MesloLGS NF' 12–13pt (see README.md)"
        echo ""
        echo "  Optional (Vim/Neovim users, X11 only):"
        echo "    • ./scripts/install-x11.sh     — Caps Lock = Ctrl (hold) / Escape (tap)"
        ;;
    docker)
        echo "    • Interactive sessions (docker exec -it ... bash) will auto-switch to zsh"
        echo "    • For Dockerfile entrypoints: source ~/.zshrc or use CMD [\"/bin/zsh\"]"
        echo ""
        echo "  Not installed (headless environment — run on a local X11 workstation):"
        echo "    • Font:  ./scripts/install-fonts.sh  — MesloLGS NF for terminal icons"
        echo "    • X11:   ./scripts/install-x11.sh   — Caps Lock remapping (Vim users)"
        ;;
esac
echo ""
