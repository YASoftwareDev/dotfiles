#!/usr/bin/env bash
# Assert the nvim config stays readable on a terminal that cannot carry truecolor.
#
# Issue #53: nightfly defines only gui colours (measured: Normal and Comment carry
# no ctermfg/ctermbg at all), while init.lua forced `termguicolors` on. A terminal
# that cannot parse `38;2;R;G;B` was then left with nothing to fall back to, which
# renders as near-black text on a near-black background.
#
# Two arms, because a fix that made every host readable by downgrading everyone
# would be a regression for the hosts that were fine:
#   low colour  (TERM=xterm)          -> some scheme with real ctermfg AND ctermbg
#   256 colour  (TERM=xterm-256color) -> nightfly and termguicolors, unchanged
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INIT="$DOTFILES_DIR/nvim/.config/nvim/init.lua"

_fail=0
_ran=0
_err() { printf '  ERROR: %s\n' "$1"; _fail=1; _ran=$(( _ran + 1 )); }
_ok()  { printf '  OK: %s\n' "$1"; _ran=$(( _ran + 1 )); }

if ! command -v nvim >/dev/null 2>&1; then
    echo "RESULT: SKIPPED and not verified - nvim is not installed"
    exit 0
fi

tmp=$(mktemp -d)
# shellcheck disable=SC2064
trap "rm -rf '$tmp'" EXIT

cat > "$tmp/probe.lua" <<'LUA'
local f = io.open(os.getenv('NVCOLOUR_OUT'), 'w')
local h = vim.api.nvim_get_hl(0, { name = 'Normal' })
f:write(string.format('scheme=%s tgc=%s ctermfg=%s ctermbg=%s\n',
  tostring(vim.g.colors_name), tostring(vim.o.termguicolors),
  tostring(h.ctermfg), tostring(h.ctermbg)))
f:close()
LUA

# A PTY is required: without one nvim takes a different startup path entirely.
_probe() { # $1 = TERM value, prints the probe line
    local out="$tmp/out.$1"
    NVCOLOUR_OUT="$out" TERM="$1" COLORTERM='' timeout 180 script -qec \
        "nvim --clean -u '$INIT' -c 'luafile $tmp/probe.lua' -c 'qa!'" /dev/null \
        >/dev/null 2>&1 || true
    [ -f "$out" ] && cat "$out" || echo "scheme=NONE tgc=? ctermfg=? ctermbg=?"
}

echo "arm 1: low-colour terminal (TERM=xterm)"
low=$(_probe xterm)
echo "  $low"
case "$low" in
    *"ctermbg=nil"*|*"ctermbg=?"*)
        _err "no ctermbg on a low-colour terminal - the buffer has no readable background" ;;
    *"ctermfg=nil"*)
        _err "no ctermfg on a low-colour terminal - text falls back to the terminal default" ;;
    *) _ok "low-colour terminal gets a scheme with real cterm colours" ;;
esac
case "$low" in
    *"tgc=true"*) _err "termguicolors still on for a low-colour terminal - RGB it cannot parse" ;;
    *)            _ok "termguicolors off for a low-colour terminal" ;;
esac

echo "arm 2: 256-colour terminal (TERM=xterm-256color) - must be unchanged"
hi=$(_probe xterm-256color)
echo "  $hi"
_skipped=""
_data=$(nvim --headless -c 'lua io.write(vim.fn.stdpath("data"))' -c 'qa!' 2>/dev/null || true)
if [ -z "$_data" ]; then
    # Never let a failed probe read as "nothing to check": that would skip arm 2
    # on every run while the verdict still said PASSED.
    _err "could not resolve nvim's data dir - cannot tell whether nightfly is installed"
elif [ ! -d "$_data/lazy/nightfly" ]; then
    # Arm 2 asserts the scheme is still nightfly, which needs the plugin on disk.
    # Without it this arm would fail for a reason that is not the defect under test.
    _skipped="arm 2 (the nightfly plugin is not installed)"
    echo "  SKIP: $_skipped"
else
    case "$hi" in
        *"scheme=nightfly"*) _ok "256-colour terminal keeps nightfly" ;;
        *)                   _err "256-colour terminal no longer gets nightfly - this is a regression" ;;
    esac
    case "$hi" in
        *"tgc=true"*) _ok "256-colour terminal keeps termguicolors" ;;
        *)            _err "256-colour terminal lost termguicolors - this is a regression" ;;
    esac
fi

echo
_verdict=$([ "$_fail" -eq 0 ] && echo PASSED || echo FAILED)
if [ -n "$_skipped" ]; then
    printf 'RESULT: %s (%d checks ran), 2 checks SKIPPED and not verified - %s\n' \
        "$_verdict" "$_ran" "$_skipped"
else
    printf 'RESULT: %s (%d checks ran, none skipped)\n' "$_verdict" "$_ran"
fi
exit "$_fail"
