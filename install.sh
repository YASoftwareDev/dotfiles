#!/usr/bin/env bash
# YA Dotfiles — main installer
#
# Usage:
#   ./install.sh                  # interactive wizard (recommended for first-timers)
#   ./install.sh minimal          # zsh + tmux + git config only
#   ./install.sh workstation      # everything (default for non-interactive runs)
#   ./install.sh docker           # headless, CI-friendly, no shell change
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
        echo "    • Start a new terminal session (or: exec zsh)"
        echo "    • Run p10k configure to customise your prompt"
        ;;
    docker)
        echo "    • Source ~/.zshrc in your entrypoint"
        ;;
esac
echo ""
