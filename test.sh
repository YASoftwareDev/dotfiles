#!/usr/bin/env bash
# Automated post-install test suite
#
# Usage:
#   bash test.sh [PROFILE]      # PROFILE: docker | minimal | workstation | nosudo (default: docker)
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
_skip() { echo -e "  ${YELLOW}–${NC}  $1 (skip: $2)"; SKIP=$((SKIP+1)); }
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
check_cmd python3
check_cmd fzf
check_cmd rg   "ripgrep"
check_cmd delta "git-delta"
check_cmd zoxide
check_cmd jq

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

# ── 10. zoxide functional ─────────────────────────────────────────────────────
_hdr "zoxide"
check_run "zoxide init bash runs" bash -c 'eval "$(zoxide init bash)"'
check_run "zoxide add + query" \
    bash -c 'eval "$(zoxide init bash)"; zoxide add /tmp; zoxide query tmp | grep -q tmp'

# ── 11. Profile-specific: minimal ─────────────────────────────────────────────
if [ "$PROFILE" = "minimal" ] || [ "$PROFILE" = "workstation" ]; then
    _hdr "Minimal tools"
    check_cmd ranger
    check_cmd tig
    check_cmd parallel
    check_cmd eza
    check_cmd shellcheck
fi

# ── 12. Profile-specific: workstation ─────────────────────────────────────────
if [ "$PROFILE" = "workstation" ]; then
    _hdr "Workstation tools"
    check_cmd nvim
    check_cmd uv
    check_cmd cheat

    _hdr "Workstation config symlinks"
    check_link ~/.config/nvim
    check_link ~/.config/ripgrep/rc
    check_link ~/.config/ranger/rc.conf
    check_link ~/.config/ranger/rifle.conf
    check_link ~/.config/ranger/scope.sh

    _hdr "Workstation tmux plugins"
    check_dir ~/.tmux/plugins/tmux-fzf  "tmux-fzf"
    check_dir ~/.tmux/plugins/tmux-cpu  "tmux-cpu"
fi

# ── 13. Profile-specific: nosudo ──────────────────────────────────────────────
# In the no-sudo environment every binary is fetched from GitHub and placed in
# ~/.local/bin.  Verify each one is present, executable, and functional.
if [ "$PROFILE" = "nosudo" ]; then
    _hdr "No-sudo: ~/.local/bin binaries"

    check_local_bin() {
        local cmd="$1" label="${2:-$1}"
        local p="$HOME/.local/bin/$cmd"
        if [ -x "$p" ]; then
            _ok "$label  →  $p  ($("$p" --version 2>&1 | head -1))"
        else
            # Strict: must be in ~/.local/bin — not just anywhere on PATH.
            # For nosudo-forced this verifies NOSUDO=1 was respected (sudo was
            # available but binaries still landed in ~/.local/bin, not /usr/local/bin).
            _fail "$label not found in ~/.local/bin (got: $(command -v "$cmd" 2>/dev/null || echo 'missing'))"
        fi
    }

    check_local_bin rg   "ripgrep"
    check_local_bin fd   "fd"
    check_local_bin jq   "jq"
    check_local_bin fzf  "fzf"
    check_local_bin zoxide "zoxide"
    check_local_bin delta  "git-delta"
    check_local_bin eza    "eza"

    _hdr "No-sudo: sudo availability"
    # nosudo-auto:   sudo binary absent → detect_sudo() auto-detected CAN_SUDO=false
    # nosudo-forced: sudo binary present but NOSUDO=1 overrides it → install still
    #                uses ~/.local/bin; sudo availability itself is not the invariant.
    # The real invariant (NOSUDO respected) is already verified by check_local_bin above.
    if sudo -v 2>/dev/null; then
        _ok "sudo available — NOSUDO=1 override mode (binaries forced to ~/.local/bin)"
    else
        _ok "sudo not available — auto-detect mode (CAN_SUDO=false)"
    fi

    _hdr "No-sudo: functional smoke tests"
    if command -v rg &>/dev/null; then
        check_run "ripgrep can search" bash -c 'echo hello | rg hello'
    fi
    if command -v fd &>/dev/null; then
        check_run "fd can search files" bash -c 'fd . /tmp --max-depth 1 | grep -q .'
    fi
    if command -v jq &>/dev/null; then
        check_run "jq can parse JSON" bash -c 'echo "{\"x\":1}" | jq .x | grep -q 1'
    fi
    if command -v fzf &>/dev/null; then
        check_run "fzf non-interactive filter" \
            bash -c 'result=$(printf "apple\nbanana\n" | fzf --filter=ban); [ "$result" = "banana" ]'
    fi
    if command -v zoxide &>/dev/null; then
        check_run "zoxide init" bash -c 'eval "$(zoxide init bash)"'
    fi
    if command -v eza &>/dev/null; then
        check_run "eza can list files" bash -c 'eza /tmp | grep -q .'
    fi
    if command -v delta &>/dev/null; then
        check_run "delta --version runs" delta --version
    fi
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
