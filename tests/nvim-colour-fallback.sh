#!/usr/bin/env bash
# Assert the nvim config stays readable on a terminal that cannot carry truecolor.
#
# Issue #53: nightfly defines only gui colours, so forcing `termguicolors` on a
# chain that cannot deliver 24-bit colour left nothing readable. Two distinct
# chains produce that, and the second is the one a first attempt missed:
#
#   direct   - $TERM itself is a low-colour terminal.
#   via tmux - $TERM inside tmux is ALWAYS tmux's own (tmux-256color) and says
#              nothing about the client; tmux quantizes whatever nvim emits down
#              to the attached client's palette. Measured 2026-09-18 with an
#              8-colour client, nightfly's truecolor arrived as blue-on-black
#              across 9.8% of the screen.
#
# The fix gates ONLY `termguicolors`; it must not switch colorscheme. Switching
# was measured actively harmful: habamax and retrobox set 256-colour greys
# (ctermfg=251/ctermbg=234) which both collapse to black once quantized to 8
# colours - 67% of the screen black-on-black, far worse than the bug. Arm 4 pins
# that, because it is the trap a future change is most likely to walk back into.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT="$DOTFILES_DIR/nvim/.config/nvim/init.lua"

_fail=0
_ran=0
_skipped=""
_err() { printf '  ERROR: %s\n' "$1"; _fail=1; _ran=$(( _ran + 1 )); }
_ok()  { printf '  OK: %s\n' "$1"; _ran=$(( _ran + 1 )); }

if ! command -v nvim >/dev/null 2>&1; then
    echo "RESULT: SKIPPED and not verified - nvim is not installed"
    exit 0
fi
if ! command -v script >/dev/null 2>&1; then
    echo "RESULT: SKIPPED and not verified - script(1) is needed to give nvim a PTY"
    exit 0
fi

tmp=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" EXIT

cat > "$tmp/probe.lua" <<'LUA'
local f = io.open(os.getenv('NVCOLOUR_OUT'), 'w')
local h = vim.api.nvim_get_hl(0, { name = 'Normal' })
f:write(string.format('tgc=%s scheme=%s ctermfg=%s ctermbg=%s\n',
  tostring(vim.o.termguicolors), tostring(vim.g.colors_name),
  tostring(h.ctermfg), tostring(h.ctermbg)))
f:close()
LUA

_probe() { # $1 = TERM; echoes the probe line
    local out="$tmp/out.$1"
    NVCOLOUR_OUT="$out" TERM="$1" COLORTERM='' TMUX='' timeout 180 script -qec \
        "nvim --clean -u '$INIT' -c 'luafile $tmp/probe.lua' -c 'qa!'" /dev/null \
        >/dev/null 2>&1 || true
    if [ -f "$out" ]; then cat "$out"; else echo "tgc=? scheme=NONE ctermfg=? ctermbg=?"; fi
}

# ── arm 1: a low-colour terminal, no tmux ────────────────────────────────────
echo "arm 1: direct low-colour terminal (TERM=xterm)"
low=$(_probe xterm)
echo "  $low"
case "$low" in
    *"tgc=false"*) _ok "termguicolors off - nvim will not emit RGB it cannot deliver" ;;
    *"tgc=?"*)     _err "probe produced no result - cannot tell, which is not a pass" ;;
    *)             _err "termguicolors still on for a low-colour terminal" ;;
esac

# ── arm 2: a 256-colour terminal must be completely unchanged ────────────────
echo "arm 2: direct 256-colour terminal (TERM=xterm-256color) - must be unchanged"
hi=$(_probe xterm-256color)
echo "  $hi"
case "$hi" in
    *"tgc=true"*) _ok "termguicolors kept for a 256-colour terminal" ;;
    *)            _err "a 256-colour terminal lost termguicolors - that is a regression" ;;
esac

# ── arm 3: inside tmux with an 8-colour CLIENT ───────────────────────────────
# The case a first fix missed entirely, because $TERM inside tmux carries '256'.
echo "arm 3: inside tmux, 8-colour client (the case \$TERM cannot reveal)"
if ! command -v tmux >/dev/null 2>&1; then
    _skipped="arm 3 (tmux is not installed)"
    echo "  SKIP: $_skipped"
else
    sock=$(mktemp -u /tmp/nvcolXXXX)   # short path: a UNIX socket dies past ~107 chars
    dec="$tmp/tmuxdec"
    tmux -S "$sock" kill-server 2>/dev/null || true
    TERM=xterm-256color tmux -S "$sock" new-session -d -x 100 -y 30 >/dev/null 2>&1 || true
    TERM=xterm timeout 90 script -qec "tmux -S $sock attach" /dev/null >/dev/null 2>&1 </dev/null &
    _sp=$!
    _client=""
    for _ in $(seq 1 20); do
        _client=$(tmux -S "$sock" display-message -p '#{client_termname}' 2>/dev/null || true)
        [ -n "$_client" ] && break
        sleep 1
    done
    if [ "$_client" != xterm ]; then
        _skipped="arm 3 (no 8-colour tmux client attached; saw '${_client:-none}')"
        echo "  SKIP: $_skipped"
    else
        # nvim writes the answer itself from `-c`, so nothing depends on keystroke
        # timing: typing `:call ...` after a fixed sleep raced a cold start in CI.
        # The command goes through a script file to keep the quoting readable.
        cat > "$tmp/arm3.sh" <<SH
nvim --clean -u '$INIT' -c "call writefile([&termguicolors], '$dec')" -c 'qa!'
SH
        tmux -S "$sock" send-keys "bash '$tmp/arm3.sh'" Enter
        # Poll for the answer rather than sleeping a guessed amount: a cold nvim
        # may bootstrap plugins first.
        for _ in $(seq 1 120); do
            [ -s "$dec" ] && break
            sleep 1
        done
        if [ ! -s "$dec" ]; then
            _err "arm 3 produced no result - cannot tell, which is not a pass"
        elif [ "$(cat "$dec")" = 0 ]; then
            _ok "termguicolors off for an 8-colour tmux client"
        else
            _err "termguicolors still on inside tmux with an 8-colour client - \$TERM was trusted"
        fi
    fi
    tmux -S "$sock" kill-server 2>/dev/null || true
    wait "$_sp" 2>/dev/null || true
fi

# ── arm 4: the low-colour path must not adopt a 232-255 grey scheme ──────────
# Both halves of a Normal in that ramp quantize to black on an 8-colour chain.
echo "arm 4: the low-colour path must not land on a 256-grey colorscheme"
_cf=$(printf '%s' "$low" | sed -n 's/.*ctermfg=\([0-9]*\).*/\1/p')
_cb=$(printf '%s' "$low" | sed -n 's/.*ctermbg=\([0-9]*\).*/\1/p')
if [ -n "$_cf" ] && [ -n "$_cb" ] \
        && [ "$_cf" -ge 232 ] && [ "$_cf" -le 255 ] \
        && [ "$_cb" -ge 232 ] && [ "$_cb" -le 255 ]; then
    _err "Normal is ctermfg=$_cf/ctermbg=$_cb - both in the 232-255 grey ramp, which collapses to black on black"
else
    _ok "Normal does not sit entirely in the 232-255 grey ramp (ctermfg=${_cf:-unset} ctermbg=${_cb:-unset})"
fi

echo
_verdict=$([ "$_fail" -eq 0 ] && echo PASSED || echo FAILED)
if [ -n "$_skipped" ]; then
    printf 'RESULT: %s (%d checks ran), 1 check SKIPPED and not verified - %s\n' \
        "$_verdict" "$_ran" "$_skipped"
else
    printf 'RESULT: %s (%d checks ran, none skipped)\n' "$_verdict" "$_ran"
fi
exit "$_fail"
