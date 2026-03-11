#!/usr/bin/env bash
# Automated post-install test suite
#
# Usage:
#   bash test.sh [PROFILE]      # PROFILE: docker | minimal | workstation (default: docker)
#
# Run inside a freshly built container:
#   docker run --rm dotfiles-test bash /root/dotfiles/test.sh
#   docker run --rm dotfiles-test bash /root/dotfiles/test.sh workstation
#
# Exit code: 0 = all passed, 1 = one or more failures

export PATH="$HOME/.local/bin:$PATH"

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/utils.sh
source "${DOTFILES_DIR}/lib/utils.sh"

PROFILE="${1:-docker}"
PASS=0
FAIL=0
SKIP=0

_ok()   { echo -e "  ${GREEN}✓${NC}  $*"; PASS=$((PASS+1)); }
_fail() { echo -e "  ${RED}✗${NC}  $*" >&2; FAIL=$((FAIL+1)); }
_skip() { echo -e "  ${YELLOW}–${NC}  $* (skip: $2)"; SKIP=$((SKIP+1)); }
_hdr()  { echo -e "\n${BOLD}── $* ──${NC}"; }

# ── Helpers ───────────────────────────────────────────────────────────────────
check_cmd() {
    local cmd="$1" label="${2:-$1}"
    if command -v "$cmd" &>/dev/null; then
        _ok "$label  →  $(command -v "$cmd")  ($(${cmd} --version 2>&1 | head -1))"
    else
        _fail "$label not found"
    fi
}

check_link() {
    local path="$1"
    if [ -L "$path" ]; then
        _ok "symlink  $path  →  $(readlink "$path")"
    elif [ -e "$path" ]; then
        _fail "$path exists but is not a symlink"
    else
        _fail "$path missing"
    fi
}

check_dir() {
    local path="$1" label="${2:-$1}"
    if [ -d "$path" ]; then
        _ok "dir  $label"
    else
        _fail "dir missing: $label"
    fi
}

check_file() {
    local path="$1" label="${2:-$1}"
    if [ -f "$path" ]; then
        _ok "file  $label"
    else
        _fail "file missing: $label"
    fi
}

# Run a command; report pass/fail with a label
check_run() {
    local label="$1"; shift
    if "$@" &>/dev/null; then
        _ok "$label"
    else
        _fail "$label  (command: $*)"
    fi
}

# ── 1. Environment ─────────────────────────────────────────────────────────────
_hdr "Environment"

if [ -n "${SHELL:-}" ]; then
    _ok "\$SHELL = $SHELL"
else
    _fail "\$SHELL is unset"
fi

if echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin"; then
    _ok "~/.local/bin on PATH"
else
    _fail "~/.local/bin not on PATH"
fi

if [ -n "${LANG:-}" ] || locale 2>/dev/null | grep -q 'UTF-8'; then
    _ok "locale  ($(locale 2>/dev/null | grep LANG= || echo 'not set — may be OK in docker'))"
else
    _skip "locale" "not critical in docker"
fi

# ── 2. Symlinks ────────────────────────────────────────────────────────────────
_hdr "Symlinks"
check_link ~/.zshrc
check_link ~/.tmux.conf
check_link ~/.tmux.conf.local
check_link ~/.gitconfig
check_link ~/.gitattributes

# ── 3. Core tools ──────────────────────────────────────────────────────────────
_hdr "Core tools"
check_cmd zsh
check_cmd tmux
check_cmd git
check_cmd fzf
check_cmd rg   "ripgrep"
check_cmd zoxide

# fd is installed as fdfind on Debian/Ubuntu; shim may live in ~/.local/bin
if command -v fd &>/dev/null; then
    _ok "fd  →  $(command -v fd)  ($(fd --version 2>&1 | head -1))"
elif command -v fdfind &>/dev/null; then
    _ok "fd (as fdfind)  →  $(command -v fdfind)"
else
    _fail "fd / fdfind not found"
fi

# ── 4. fzf shell integration ───────────────────────────────────────────────────
_hdr "fzf shell integration"
# fzf is installed via git clone to ~/.fzf; the installer generates ~/.fzf.zsh
check_dir ~/.fzf "~/.fzf (git clone)"
check_file ~/.fzf.zsh "~/.fzf.zsh (shell integration)"

if [ -f ~/.fzf.zsh ]; then
    check_run "~/.fzf.zsh sources without error" zsh -c "source ~/.fzf.zsh"
fi

# ── 5. fzf functional ─────────────────────────────────────────────────────────
_hdr "fzf functional"

check_run "fzf --filter (non-interactive filtering)" \
    bash -c 'result=$(printf "apple\nbanana\ncherry\n" | fzf --filter=ban); [ "$result" = "banana" ]'

check_run "fzf --version runs" fzf --version

# ── 6. zsh config ─────────────────────────────────────────────────────────────
_hdr "zsh config"
check_run "~/.zshrc syntax check (zsh -n)" zsh -n ~/.zshrc

# ── 7. oh-my-zsh ──────────────────────────────────────────────────────────────
_hdr "oh-my-zsh"
check_dir ~/.oh-my-zsh
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
check_dir "$ZSH_CUSTOM/themes/powerlevel10k"
check_dir "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
check_dir "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
check_dir "$ZSH_CUSTOM/plugins/fzf-tab"

# ── 8. tmux ────────────────────────────────────────────────────────────────────
_hdr "tmux"
if command -v tmux &>/dev/null; then
    export TERM="${TERM:-xterm-256color}"
    if tmux -f ~/.tmux.conf new-session -d -s dotfiles_test 2>/dev/null; then
        tmux kill-session -t dotfiles_test 2>/dev/null || true
        _ok "tmux config loads in detached session"
    else
        _fail "tmux failed to start with ~/.tmux.conf"
    fi
else
    _fail "tmux not installed"
fi

# ── 9. git config ─────────────────────────────────────────────────────────────
_hdr "git config"
check_run "dotfiles git settings applied" \
    bash -c 'git config --global diff.zip.textconv | grep -q unzip'

# ── 10. zoxide ────────────────────────────────────────────────────────────────
_hdr "zoxide"
if command -v zoxide &>/dev/null; then
    check_run "zoxide init bash runs" bash -c 'eval "$(zoxide init bash)"'
    check_run "zoxide add + query" \
        bash -c 'eval "$(zoxide init bash)"; zoxide add /tmp; zoxide query tmp | grep -q tmp'
else
    _fail "zoxide not installed"
fi

# ── 11. Profile-specific: minimal ─────────────────────────────────────────────
if [ "$PROFILE" = "minimal" ] || [ "$PROFILE" = "workstation" ]; then
    _hdr "Minimal tools"
    check_cmd ranger
    check_cmd tig
    check_cmd parallel
fi

# ── 12. Profile-specific: workstation ─────────────────────────────────────────
if [ "$PROFILE" = "workstation" ]; then
    _hdr "Workstation tools"
    check_cmd nvim
    check_cmd delta
    check_cmd uv
    check_cmd cheat

    _hdr "Workstation config symlinks"
    check_link ~/.config/nvim
    check_link ~/.config/ripgrep/rc
    check_link ~/.config/ranger/rc.conf
    check_link ~/.config/ranger/rifle.conf
    check_link ~/.config/ranger/scope.sh
fi

# ── Summary ───────────────────────────────────────────────────────────────────
TOTAL=$((PASS+FAIL+SKIP))
echo ""
echo -e "${BOLD}── Results (profile: $PROFILE) ──${NC}"
echo -e "  ${GREEN}✓${NC}  Passed:  $PASS / $TOTAL"
[ "$SKIP" -gt 0 ] && echo -e "  ${YELLOW}–${NC}  Skipped: $SKIP / $TOTAL"
if [ "$FAIL" -gt 0 ]; then
    echo -e "  ${RED}✗${NC}  Failed:  $FAIL / $TOTAL"
    echo ""
    exit 1
fi
echo ""
