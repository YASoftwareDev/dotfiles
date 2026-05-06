#!/usr/bin/env bash
# YA Dotfiles - main installer
#
# Usage:
#   ./install.sh                        # interactive wizard (recommended for first-timers)
#   ./install.sh minimal                # zsh + tmux + git config only
#   ./install.sh workstation            # everything (default for non-interactive runs)
#   ./install.sh docker                 # headless, CI-friendly, no shell change
#   NOSUDO=1 ./install.sh workstation   # force user-local (~/.local/bin) installs, skip apt
#   ./install.sh --nosudo workstation   # same as above via flag (works in curl-pipe)
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
    echo -e "║      YA Dotfiles - Environment Setup     ║"
    echo -e "╚══════════════════════════════════════════╝${NC}"
    echo ""
}

# ── Interactive profile wizard ────────────────────────────────────────────────
_wizard() {
    # All display output goes to stderr so the menu is visible when called
    # inside $(...) command substitution to capture only the profile name.
    echo "  What kind of environment are you setting up?" >&2
    echo "" >&2
    echo "    1) minimal      - zsh, tmux, git config            (~5 min)" >&2
    echo "    2) workstation  - everything: editor + all tools   (~15 min)" >&2
    echo "    3) docker       - headless, CI-friendly, no fonts  (~3 min)" >&2
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

# ── Post-install state detection ──────────────────────────────────────────────
# Reads actual system state so the summary is accurate on first install,
# re-run, or update over existing dotfiles.
# NXS_* are intentional global outputs of this function - not declared local.
_compute_next_steps_state() {
    local _zsh_bin _pw_shell _font_dir

    # zsh binary location
    _zsh_bin=$(command -v zsh 2>/dev/null || true)
    NXS_ZSH_BIN="${_zsh_bin}"

    # Login shell - read from passwd by UID (avoids username-parsing edge cases).
    # Do NOT use $SHELL: it is a login-time snapshot and is stale after chsh/usermod.
    _pw_shell=$(getent passwd "$(id -u)" 2>/dev/null | cut -d: -f7 \
        || awk -F: -v u="$(id -u)" '$3==u{print $7; exit}' /etc/passwd 2>/dev/null \
        || echo "")
    NXS_ZSH_IS_DEFAULT=false
    case "${_pw_shell}" in *zsh*) NXS_ZSH_IS_DEFAULT=true ;; esac

    # Managed exec-zsh shim - match the exact line written by _patch_bashrc_for_docker.
    # Uses fixed-string (-F) to avoid treating shell metacharacters as regex.
    NXS_BASHRC_EXECZSH=false
    grep -qF '[ -z "$ZSH_VERSION" ] && [ -t 0 ] && exec zsh' \
        "${HOME}/.bashrc" 2>/dev/null && NXS_BASHRC_EXECZSH=true

    # Current running process is zsh (ZSH_VERSION is set for all zsh invocation modes)
    NXS_IN_ZSH=false
    [ -n "${ZSH_VERSION:-}" ] && NXS_IN_ZSH=true

    # p10k wizard has been run before?
    NXS_P10K_CONFIGURED=false
    [ -f "${HOME}/.p10k.zsh" ] && NXS_P10K_CONFIGURED=true

    # Running over SSH?
    NXS_OVER_SSH=false
    { [ -n "${SSH_CLIENT:-}" ] || [ -n "${SSH_TTY:-}" ] \
        || [ -n "${SSH_CONNECTION:-}" ]; } && NXS_OVER_SSH=true

    # Font state - four values, because over SSH we can only observe the remote host,
    # not the local terminal that actually renders glyphs:
    #   installed     - fontconfig indexes MesloLGS NF (fc-list confirms)
    #   cache_stale   - font files present in FONT_DIR but fc-cache not yet run
    #   missing       - no font files found on this machine
    #   unknown_remote - over SSH; cannot inspect the local terminal from here
    _font_dir="${HOME}/.local/share/fonts/MesloLGS-NF"
    NXS_FONTS_STATE="unknown_remote"
    if ! $NXS_OVER_SSH; then
        if command -v fc-list &>/dev/null \
                && fc-list 2>/dev/null | grep -qi "MesloLGS"; then
            NXS_FONTS_STATE="installed"
        elif find "${_font_dir}" -name "*.ttf" 2>/dev/null | grep -q .; then
            NXS_FONTS_STATE="cache_stale"
        else
            NXS_FONTS_STATE="missing"
        fi
    fi

    # Local graphical X11 session - gate on NOT over SSH so we don't mistake
    # SSH X-forwarding ($DISPLAY set remotely) for a local desktop session.
    # install-x11.sh installs autostart hooks for the remote machine's own login
    # session; showing it for SSH X-forwarding would be confusing and wrong.
    NXS_X11_LOCAL=false
    [ -n "${DISPLAY:-}" ] && ! $NXS_OVER_SSH && NXS_X11_LOCAL=true

    # Caps-Lock remap fully installed?
    NXS_CAPS_REMAP_DONE=false
    { command -v xcape &>/dev/null \
        && [ -f "${HOME}/.config/autostart/caps-remap.desktop" ]; } \
        && NXS_CAPS_REMAP_DONE=true
}

# ── Main ──────────────────────────────────────────────────────────────────────
_banner

# Determine profile: arg > wizard (if interactive) > default
# Also accept --nosudo flag (needed when called from curl-pipe where env prefix
# would only apply to curl, not bash: curl ... | bash -s -- --nosudo workstation)
PROFILE=""
for _arg in "$@"; do
    case "$_arg" in
        --nosudo) export NOSUDO=1 ;;
        *)        PROFILE="$_arg" ;;
    esac
done
unset _arg
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

_compute_next_steps_state

echo ""
log_ok "Setup complete!"
echo ""

case "$PROFILE" in
    minimal|workstation)
        # _nxs_action counts items requiring action on THIS machine.
        # The font advisory shown when over SSH is informational only and is not
        # counted - fonts live on the local terminal, not the remote host.
        _nxs_action=0

        echo "  Next steps:"

        # ── Shell ────────────────────────────────────────────────────────────
        if [ -z "$NXS_ZSH_BIN" ]; then
            # zsh was not installed (should be rare - install_base handles it)
            echo "    - zsh not found - install it, then re-run:"
            echo "        bash '${DOTFILES_DIR}/install.sh' ${PROFILE}"
            _nxs_action=$(( _nxs_action + 1 ))
        elif $NXS_IN_ZSH; then
            : # Already running in zsh - nothing needed
        elif $NXS_ZSH_IS_DEFAULT; then
            # Login shell is zsh but this session is not (common on re-runs from bash)
            echo "    - Activate zsh for this session:  exec zsh"
            _nxs_action=$(( _nxs_action + 1 ))
        elif $NXS_BASHRC_EXECZSH; then
            # Docker shim present - interactive bash will auto-exec zsh
            echo "    - Interactive bash sessions auto-exec zsh (via .bashrc)"
            echo "      Activate now:  exec zsh"
            _nxs_action=$(( _nxs_action + 1 ))
        else
            # Login shell is not yet zsh and no shim
            echo "    - Set default shell to zsh:  chsh -s ${NXS_ZSH_BIN}  (next login)"
            echo "      Or activate now:            exec zsh"
            _nxs_action=$(( _nxs_action + 1 ))
        fi

        # ── p10k ─────────────────────────────────────────────────────────────
        if ! $NXS_P10K_CONFIGURED && [ -n "$NXS_ZSH_BIN" ]; then
            if $NXS_IN_ZSH; then
                echo "    - Configure prompt now:  p10k configure"
            else
                echo "    - Once in zsh:  p10k configure   (sets prompt style + installs fonts)"
            fi
            _nxs_action=$(( _nxs_action + 1 ))
        fi

        # ── Fonts (local - actionable) ────────────────────────────────────────
        case "$NXS_FONTS_STATE" in
            installed)
                : # Nothing to show
                ;;
            cache_stale)
                # Font files exist but fc-cache hasn't indexed them yet
                echo "    - Font files present but fontconfig cache is stale - run:"
                echo "        fc-cache -f"
                _nxs_action=$(( _nxs_action + 1 ))
                ;;
            missing)
                echo ""
                echo "  Font - MesloLGS NF (for prompt icons, install on this machine):"
                if ! $NXS_P10K_CONFIGURED; then
                    echo "    Option A (easiest): p10k configure - wizard installs fonts + sets prompt"
                fi
                echo "    Option B (script):  ~/.dotfiles/scripts/install-fonts.sh"
                echo "    Option C (curl):    bash <(curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/scripts/install-fonts.sh)"
                echo "    Then set terminal font to 'MesloLGS NF' 12-13pt (see README.md)"
                _nxs_action=$(( _nxs_action + 1 ))
                ;;
            unknown_remote)
                : # Advisory shown after the action summary below
                ;;
        esac

        # ── X11 caps remap ───────────────────────────────────────────────────
        # Only shown for local graphical sessions - not SSH X-forwarding.
        if $NXS_X11_LOCAL && ! $NXS_CAPS_REMAP_DONE; then
            echo ""
            echo "  Optional (Vim/Neovim users, local X11 desktop):"
            echo "    - ~/.dotfiles/scripts/install-x11.sh  - Caps Lock = Ctrl (hold) / Escape (tap)"
            _nxs_action=$(( _nxs_action + 1 ))
        fi

        # ── All done ─────────────────────────────────────────────────────────
        if [ "$_nxs_action" -eq 0 ]; then
            echo "    ✓ All post-install steps already complete - nothing more to do."
        fi

        # ── Font advisory (SSH only - shown after action summary) ─────────────
        # Cannot confirm whether the local terminal has the font from a remote host.
        # Show as a lightweight reminder, not an action item.
        if [ "$NXS_FONTS_STATE" = "unknown_remote" ]; then
            echo ""
            echo "  Font - if your local terminal lacks MesloLGS NF, install it on"
            echo "  the machine you SSH from (not this server):"
            echo "    - Script:  bash <(curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/scripts/install-fonts.sh)"
            echo "    - Then set your local terminal font to 'MesloLGS NF' 12-13pt"
        fi
        ;;

    docker)
        echo "  Next steps:"
        echo "    - Interactive sessions (docker exec -it ... bash) will auto-switch to zsh"
        echo "    - For Dockerfile entrypoints: source ~/.zshrc or use CMD [\"/bin/zsh\"]"
        echo ""
        echo "  Not installed (headless environment - run on a local workstation):"
        echo "    - Font:  ~/.dotfiles/scripts/install-fonts.sh  - MesloLGS NF for terminal icons"
        echo "           or: bash <(curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/scripts/install-fonts.sh)"
        echo "    - X11:   ~/.dotfiles/scripts/install-x11.sh   - Caps Lock remapping (Vim users)"
        ;;
esac
echo ""
