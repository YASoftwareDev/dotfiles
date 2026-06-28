#!/usr/bin/env bash
# Claude Code Stop hook — automatic static gate for code changes in this repo.
#
# Fires when the agent finishes a turn. For each CHANGED, TRACKED shell/zsh
# script it runs reliable, zero-false-positive static checks and BLOCKS the
# stop on a regression (emits {"decision":"block","reason":...} on stdout), so
# the task is not "complete" until the agent fixes it.
#
# WHAT IT CHECKS (and why only this):
#   • bash -n     — syntax of changed *.sh (a changed script must parse).
#   • shellcheck  — but BASELINE-COMPARED against HEAD: only NEW findings block,
#                   so a file's pre-existing warnings never trap unrelated edits
#                   (e.g. test.sh's display-string SC2088).
#   • zsh -n      — syntax of changed .zshrc / *.zsh.
#
# WHAT IT DELIBERATELY DOES NOT DO:
#   • It does NOT run test.sh — that validates the live/INSTALLED state, not the
#     working-tree diff (an uninstalled logic change is invisible to it, and on a
#     drifted dev machine it reports unrelated failures). The meaningful run is
#     test.sh inside a fresh ci-local.sh container — mandated by CLAUDE.md and run
#     by the agent with judgment, not here.
#   • It does NOT run the Docker matrix (too slow per-turn; unauthenticated local
#     runs also trip GitHub's 60-req/hr API limit and produce false failures).
#
# Safety:
#   • Fails OPEN (allows the stop) whenever it cannot determine state.
#   • Bounded loop guard: the agent is never *permanently* trapped — a stop is
#     allowed once every MAX_BLOCKS+1 attempts (block×MAX_BLOCKS → allow, then the
#     counter resets), and it resets immediately on any clean pass. Keyed on
#     session_id (a documented Stop-hook input field). This does NOT depend on
#     `stop_hook_active`, which is not a documented Stop input field.
#
# NOTE: intentionally NO `set -e` — shellcheck/git show/comm return non-zero as a
# normal signal; statuses are handled explicitly (and guarded with `|| true`).
set -uo pipefail

MAX_BLOCKS=3

REPO="${CLAUDE_PROJECT_DIR:-}"
[ -z "$REPO" ] && REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO" 2>/dev/null || exit 0

payload="$(cat 2>/dev/null || true)"

# ── Derive a stable per-session key for the loop guard ────────────────────────
sid=""
if command -v python3 >/dev/null 2>&1; then
    sid="$(printf '%s' "$payload" | python3 -c \
        'import sys,json
try: print(json.load(sys.stdin).get("session_id",""))
except Exception: print("")' 2>/dev/null)"
fi
[ -z "$sid" ] && sid="$(printf '%s' "$payload" \
    | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 \
    | sed 's/.*"\([^"]*\)"$/\1/')"
[ -z "$sid" ] && sid="default"
sid="$(printf '%s' "$sid" | tr -c 'A-Za-z0-9._-' '_')"
guard="${TMPDIR:-/tmp}/dotfiles-stopgate-${sid}.count"

# ── Only act on real, tracked code changes ────────────────────────────────────
command -v git >/dev/null 2>&1 || { rm -f "$guard"; exit 0; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { rm -f "$guard"; exit 0; }

# Changed TRACKED files vs HEAD (staged + unstaged). Untracked files are excluded
# on purpose. core.quotepath=false keeps non-ASCII paths literal (not \nnn-escaped).
mapfile -t changed < <(git -c core.quotepath=false diff --name-only HEAD 2>/dev/null)
if [ "${#changed[@]}" -eq 0 ]; then rm -f "$guard"; exit 0; fi

# Normalize shellcheck output to location-independent findings (drop file:line:col:)
# so line shifts don't read as new warnings. Always returns 0.
_sc_findings() {
    { shellcheck -S warning -f gcc - 2>/dev/null | sed 's/^[^:]*:[0-9]*:[0-9]*: //' | sort -u; } || true
}

fails=()
for f in "${changed[@]}"; do
    [ -f "$f" ] || continue   # deleted/renamed-away: nothing to check
    case "$f" in
        *.sh)
            if ! err="$(bash -n "$f" 2>&1)"; then
                fails+=("bash -n $f: $(printf '%s' "$err" | tr '\n' ' ')")
            fi
            if command -v shellcheck >/dev/null 2>&1; then
                base_sc="$(git show "HEAD:$f" 2>/dev/null | _sc_findings)" || true
                work_sc="$(_sc_findings < "$f")" || true
                new_sc="$(comm -13 <(printf '%s\n' "$base_sc") <(printf '%s\n' "$work_sc"))" || true
                [ -n "$new_sc" ] && fails+=("shellcheck: new finding(s) in $f → $(printf '%s' "$new_sc" | tr '\n' '|')")
            fi
            ;;
        *.zshrc|*.zsh)
            if command -v zsh >/dev/null 2>&1; then
                if ! err="$(zsh -n "$f" 2>&1)"; then
                    fails+=("zsh -n $f: $(printf '%s' "$err" | tr '\n' ' ')")
                fi
            fi
            ;;
    esac
done

# ── Clean pass → reset the loop counter and allow the stop ────────────────────
if [ "${#fails[@]}" -eq 0 ]; then rm -f "$guard"; exit 0; fi

# ── Failure → bounded loop guard ──────────────────────────────────────────────
count=0
[ -f "$guard" ] && count="$(cat "$guard" 2>/dev/null || echo 0)"
case "$count" in ''|*[!0-9]*) count=0 ;; esac
count=$((count + 1))
if [ "$count" -gt "$MAX_BLOCKS" ]; then
    rm -f "$guard"   # nudged MAX_BLOCKS times — allow this stop and reset the valve
    exit 0
fi
printf '%s' "$count" > "$guard" 2>/dev/null || true

reason="Static gate failed for changed scripts in $(basename "$REPO") — not complete until fixed:"
for x in "${fails[@]}"; do reason+=$'\n  • '"$x"; done
reason+=$'\n'"Per CLAUDE.md, also run the functional suite before declaring done: bash test.sh <profile> in a fresh ci-local.sh container, and for install.sh/update.sh/modules/lib changes a ci-local.sh subset (use --skip-nosudo or one nosudo variant locally to avoid GitHub API rate limits)."

python3 -c 'import json,sys; print(json.dumps({"decision":"block","reason":sys.argv[1]}))' "$reason" 2>/dev/null \
    || printf '{"decision":"block","reason":"Static gate failed; run shellcheck/bash -n on changed scripts."}\n'
exit 0
