#!/usr/bin/env bash
# Functional test for tmux/tmux-status-rows.
#
# Runs against two throwaway tmux servers on private sockets: one holds the
# session under test, the other attaches to it so the rendered status rows can
# be captured. Nothing touches the caller's own tmux server.
#
# Usage: bash tests/tmux-status-rows.sh

set -euo pipefail

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
readonly SUT="${SCRIPT_DIR}/../tmux/tmux-status-rows"
readonly SOCK_BASE="/tmp/tmux-status-rows-test-$$"
SOCK="${SOCK_BASE}-0-sut.sock"
VIEW="${SOCK_BASE}-0-view.sock"
ROUND=0

PASS=0
FAIL=0

_ok() {
    printf '  OK: %s\n' "$1"
    PASS=$((PASS + 1))
}

_fail() {
    printf '  FAIL: %s\n' "$1"
    FAIL=$((FAIL + 1))
}

cleanup() {
    local sock
    for sock in "${SOCK_BASE}"-*.sock; do
        [ -S "$sock" ] || continue
        tmux -S "$sock" kill-server 2>/dev/null || true
        rm -f "$sock"
    done
}
trap cleanup EXIT

t() { tmux -S "$SOCK" "$@"; }

# The script under test talks to whatever server $TMUX points at, exactly as it
# does from a tmux hook - so it never reaches the caller's own tmux server.
sut() {
    local pid
    pid=$(tmux -S "$SOCK" display-message -p '#{pid}')
    TMUX="$SOCK,$pid,0" "$SUT" "$@"
}

# Start a session of $1 windows named win01..winNN, viewed at $2 x $3.
start_session() {
    local count="$1" width="$2" height="$3" i
    cleanup
    # A fresh socket per round: a just-killed server can still be shutting down
    # when the next new-session connects to it ("server exited unexpectedly").
    ROUND=$((ROUND + 1))
    SOCK="${SOCK_BASE}-${ROUND}-sut.sock"
    VIEW="${SOCK_BASE}-${ROUND}-view.sock"
    tmux -S "$SOCK" -f /dev/null new-session -d -s t -x "$width" -y "$height"
    t set -g status-left ' [t] '
    t set -g status-right ' right '
    t rename-window -t t:0 win00
    for ((i = 1; i < count; i++)); do
        t new-window -d -t t -n "$(printf 'win%02d' "$i")"
    done
    attach_view "$width" "$height"
}

# (Re)attach a viewing client of the given size, on its own socket each time.
attach_view() {
    local width="$1" height="$2"
    if [ -S "$VIEW" ]; then
        tmux -S "$VIEW" kill-server 2>/dev/null || true
        rm -f "$VIEW"
    fi
    ROUND=$((ROUND + 1))
    VIEW="${SOCK_BASE}-${ROUND}-view.sock"
    tmux -S "$VIEW" -f /dev/null new-session -d -s v -x "$width" -y "$height" \
        "tmux -S '$SOCK' attach -t t"
    sleep 0.6
}

# The status block as the attached client actually renders it.
render() {
    local lines="$1"
    # status reads back as "on" for a single row.
    case "$lines" in '' | *[!0-9]*) lines=1 ;; esac
    sut -q
    tmux -S "$VIEW" refresh-client 2>/dev/null || true
    sleep 0.5
    tmux -S "$VIEW" capture-pane -p -t v | sed -e 's/[[:space:]]*$//' | grep -v '^$' | tail -"$lines"
}

# Effective value, so the stock (global) setting reads back as well.
status_lines() { t show-options -qv -A -t t status; }

printf '== packing arithmetic (no tmux server needed) ==\n'
# The BASH_SOURCE guard at the end of the script keeps main() from running here.
# shellcheck source=../tmux/tmux-status-rows
. "$SUT"

# Two 40-column tabs, a 50-column client, status-right 30 wide. Row 1 is the
# last row, so it only has 20 columns: accepting this layout would draw a tab
# straight through status-right.
if pack 2 50 0 30 0 0 false 40 40; then
    _fail "pack accepted a 40-column last row against a capacity of 20"
else
    _ok "pack refuses a row that status-right's margin makes too small"
fi
if pack 3 50 0 30 0 0 false 40 40 && [ "${PACK_ROW[*]}" = "0 1" ]; then
    _ok "one more row available and the same tabs fit, status-right alone on the last"
else
    _fail "pack could not place two 40-column tabs across 3 rows: (${PACK_ROW[*]})"
fi
# A tab too wide for any row must still be placed - no row count can help, and
# escalating to the ceiling for it would waste rows.
if pack 1 30 0 0 0 0 true 40 && [ "${PACK_ROW[*]}" = "0" ]; then
    _ok "a tab too wide for any row is placed rather than escalating rows"
else
    _fail "a tab wider than the client was dropped"
fi

# Balancing: three narrow tabs then two wide ones. Greedy fills row 0 to the
# brim (four tabs, 58 of 60 columns) and leaves one tab alone on row 1; the
# balanced pass should split them 3/2.
pack 2 60 0 0 1 0 false 10 10 10 25 25
greedy="${PACK_ROW[*]}"
pack_balanced 2 60 0 0 1 0 10 10 10 25 25
if [ "$greedy" = "0 0 0 0 1" ] && [ "${PACK_ROW[*]}" = "0 0 0 1 1" ]; then
    _ok "rows are balanced (3/2), not filled to the brim (4/1)"
else
    _fail "balancing did not happen: greedy=($greedy) balanced=(${PACK_ROW[*]})"
fi

# Below tmux 3.2 there is no #{w:} width modifier, the script no-ops by design,
# and none of the wrapping below can happen. Skip rather than report a failure.
start_session 1 80 20
if [ "$(t display-message -p '#{w:#{host}}')" = "0" ] || [ -z "$(t display-message -p '#{w:#{host}}')" ]; then
    printf 'SKIP: %s has no #{w:} width modifier (needs tmux 3.2+)\n' "$(tmux -V)"
    exit 0
fi

printf '== few tabs, wide client: stays a single row ==\n'
start_session 4 120 20
sut -q
if [ "$(status_lines)" = "on" ] && [ -z "$(t show-options -qv -t t 'status-format[1]')" ]; then
    _ok "status stays a single row"
else
    _fail "expected one row, got status=$(status_lines)"
fi
out=$(render 1)
found=$(printf '%s\n' "$out" | grep -o 'win0[0-3]' | sort -u | tr '\n' ' ')
lines=$(printf '%s\n' "$out" | grep -c 'win0[0-3]')
if [ "$found" = "win00 win01 win02 win03 " ] && [ "$lines" = "1" ]; then
    _ok "all four tabs render, on one row"
else
    _fail "single row shows [$found] across $lines line(s): $out"
fi

printf '== many tabs, narrow client: wraps onto more rows ==\n'
start_session 14 60 24
sut -q
rows=$(status_lines)
if [ "$rows" -ge 2 ] 2>/dev/null; then
    _ok "status grew to $rows rows"
else
    _fail "expected >= 2 rows, got status=$rows"
fi

out=$(render "$rows")
missing=""
for i in $(seq 0 13); do
    name=$(printf 'win%02d' "$i")
    case "$out" in *"$name"*) ;; *) missing="$missing $name" ;; esac
done
if [ -z "$missing" ]; then
    _ok "every tab is visible across the rows"
else
    _fail "tabs hidden after wrapping:$missing"
fi

dupes=$(printf '%s\n' "$out" | grep -o 'win[0-9][0-9]' | sort | uniq -d | tr '\n' ' ')
if [ -z "$dupes" ]; then
    _ok "no tab is drawn twice"
else
    _fail "tabs drawn on more than one row: $dupes"
fi

first_row=$(printf '%s\n' "$out" | head -1)
last_row=$(printf '%s\n' "$out" | tail -1)
case "$first_row" in *'[t]'*) _ok "status-left sits on the first row" ;; *) _fail "status-left missing from first row: $first_row" ;; esac
case "$last_row" in *'right'*) _ok "status-right sits on the last row" ;; *) _fail "status-right missing from last row: $last_row" ;; esac

# capture-pane returns the screen tmux already cropped to the client width, so
# a "line longer than the client" assertion can never fail. What it can see is
# tmux's own overflow markers: "<" or ">" beside the window list mean the list
# did not fit and part of it is hidden.
markers=$(printf '%s\n' "$out" | grep -c '[<>]' || true)
if [ "$markers" = "0" ]; then
    _ok "tmux is not truncating the list (no < > markers)"
else
    _fail "tmux still truncates the window list: $out"
fi

printf '== tabs are ordered left to right, top to bottom ==\n'
order=$(printf '%s\n' "$out" | grep -o 'win[0-9][0-9]' | tr '\n' ' ')
sorted=$(printf '%s\n' "$out" | grep -o 'win[0-9][0-9]' | sort | tr '\n' ' ')
if [ "$order" = "$sorted" ]; then
    _ok "reading order preserved: $order"
else
    _fail "out of order: got [$order] want [$sorted]"
fi

printf '== resizing the client reflows the rows ==\n'
before=$(status_lines)
attach_view 240 24
sut -q
after=$(status_lines)
if [ "$after" != "$before" ]; then
    _ok "widening 60 -> 240 columns changed the layout ($before -> $after)"
else
    _fail "layout unchanged after resize (still $after)"
fi

printf '== the embedded #() driver reflows without a hook ==\n'
start_session 10 100 24
t set -g status-interval 1
sut -q
before=$(status_lines)
# Widening the tab format fires no tmux hook at all: only the #() job embedded
# in status-format[0] can notice it.
t set -g window-status-format '#I #W ---------------'
tmux -S "$VIEW" refresh-client 2>/dev/null || true
waited=0
while [ "$waited" -lt 15 ]; do
    sleep 1
    waited=$((waited + 1))
    if [ "$(status_lines)" != "$before" ]; then break; fi
done
after=$(status_lines)
if [ "$after" != "$before" ]; then
    _ok "wider tabs reflowed on their own after ${waited}s ($before -> $after)"
else
    _fail "layout never reflowed without a hook (still $after)"
fi

printf '== row ceiling is honoured ==\n'
start_session 30 40 24
t set -g @status-rows-max 3
sut -q
if [ "$(status_lines)" = "3" ]; then
    _ok "@status-rows-max 3 caps the layout at 3 rows"
else
    _fail "expected 3 rows, got $(status_lines)"
fi

printf '== status-right keeps its own room on the last row ==\n'
start_session 14 60 24
t set -g status-right ' RIGHTMARK '
# Long names so the rows pack densely - with short labels the last row ends far
# from status-right and an overlap could not show.
for i in $(seq 0 13); do
    t rename-window -t "t:$i" "$(printf 'longwindow%02d' "$i")"
done
sut -q
rows=$(status_lines)
out=$(render "$rows")
last_row=$(printf '%s\n' "$out" | tail -1)
head_of_row=${last_row%%RIGHTMARK*}
case "$head_of_row" in
    *"  ")
        _ok "the last tab ends clear of status-right"
        ;;
    *)
        _fail "status-right runs into the last tab: [$last_row]"
        ;;
esac

printf '== at the row ceiling tmux keeps its own overflow markers ==\n'
start_session 30 40 24
t set -g @status-rows-max 1
sut -q
out=$(render 1)
if printf '%s\n' "$out" | grep -q '[<>]'; then
    _ok "a row that still cannot fit shows tmux's < > markers, as stock does"
else
    _fail "tabs are clipped with no marker at all: $out"
fi

printf '== a session whose status bar is off is left alone ==\n'
start_session 14 60 24
t set -g status off
sut -q
if [ "$(status_lines)" = "off" ]; then
    _ok "status off is not overridden by a layout run"
else
    _fail "the layout run turned the status bar back on: $(status_lines)"
fi
sut --reset -q
if [ "$(status_lines)" = "off" ]; then
    _ok "--reset does not pin a session-level status either"
else
    _fail "--reset turned the status bar back on: $(status_lines)"
fi

printf '== @status-rows-reserve and --print ==\n'
start_session 14 60 24
sut -q
before=$(status_lines)
out=$(sut --print)
case "$out" in
    *"reserve=4"*) _ok "--print reports the layout it computed (reserve=4)" ;;
    *) _fail "--print did not report the default reserve: $out" ;;
esac
t set -g @status-rows-reserve 20
out=$(sut --print)
sut -q
after=$(status_lines)
case "$out" in
    *"reserve=20"*)
        if [ "$after" -gt "$before" ] 2>/dev/null; then
            _ok "a larger reserve takes columns away and costs a row ($before -> $after)"
        else
            _fail "@status-rows-reserve 20 changed nothing ($before -> $after)"
        fi
        ;;
    *) _fail "@status-rows-reserve was ignored: $out" ;;
esac

printf '== the shipped tmux.conf.local hooks reflow on real events ==\n'
HOOK_HOME="${SOCK_BASE}-home"
mkdir -p "$HOOK_HOME/.local/bin"
ln -sf "$(cd "$(dirname -- "$SUT")" && pwd)/tmux-status-rows" "$HOOK_HOME/.local/bin/tmux-status-rows"
# The block is taken from the config that actually ships, so a renamed hook, a
# wrong hook index or a broken command string fails here.
sed -n '/-- multi-row window tabs/,/^%endif/p' \
    "${SCRIPT_DIR}/../tmux/.tmux.conf.local" > "${HOOK_HOME}/rows.conf"
if [ ! -s "${HOOK_HOME}/rows.conf" ]; then
    _fail "could not extract the multi-row block from tmux/.tmux.conf.local"
else
    cleanup
    ROUND=$((ROUND + 1))
    SOCK="${SOCK_BASE}-${ROUND}-sut.sock"
    VIEW="${SOCK_BASE}-${ROUND}-view.sock"
    # The hooks call ~/.local/bin/tmux-status-rows, so the server needs a HOME
    # where that path exists.
    HOME="$HOOK_HOME" tmux -S "$SOCK" -f /dev/null new-session -d -s t -x 60 -y 24
    t set -g status-left ' [t] '
    t set -g status-right ' right '
    t rename-window -t t:0 win00
    if t source-file "${HOOK_HOME}/rows.conf"; then
        _ok "the shipped block loads without a tmux error"
    else
        _fail "tmux rejected the multi-row block from .tmux.conf.local"
    fi
    attach_view 60 24
    # No sut call anywhere below: only the hooks can produce a layout.
    for i in $(seq 1 13); do
        t new-window -d -t t -n "$(printf 'win%02d' "$i")"
    done
    waited=0
    while [ "$waited" -lt 10 ]; do
        sleep 1
        waited=$((waited + 1))
        if [ "$(status_lines)" != "on" ]; then break; fi
    done
    if [ "$(status_lines)" != "on" ]; then
        _ok "hooks alone wrapped the tabs onto $(status_lines) rows after ${waited}s"
    else
        _fail "the shipped hooks never reflowed the status (still one row)"
    fi
fi

printf '== feature switch and reset restore stock rendering ==\n'
t set -g @status-rows off
sut -q
if [ "$(status_lines)" = "on" ] &&
    [ -z "$(t show-options -qv -t t 'status-format[0]')" ] &&
    [ -z "$(t show-options -qv -t t 'status-format[1]')" ]; then
    _ok "@status-rows off unsets every status-format row"
else
    _fail "@status-rows off left status=$(status_lines) format[0]=$(t show-options -qv -t t 'status-format[0]' | head -c 40)"
fi
t set -g @status-rows on
sut -q
sut --reset -q
if [ "$(status_lines)" = "on" ] && [ -z "$(t show-options -qv -t t 'status-format[0]')" ]; then
    _ok "--reset unsets every status-format row"
else
    _fail "--reset left status=$(status_lines) format[0]=$(t show-options -qv -t t 'status-format[0]' | head -c 40)"
fi

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
