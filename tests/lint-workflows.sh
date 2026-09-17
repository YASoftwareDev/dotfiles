#!/usr/bin/env bash
# Lint the GitHub Actions workflows BEFORE pushing.
#
# Why this cannot be a CI job: an invalid workflow file runs nothing, so CI has
# no way to report the problem. Worse, once branch protection requires the
# `CI gate` check, an invalid workflow means that check never reports and the PR
# is blocked with no visible cause. This has to be caught locally.
#
# Both patterns below cost a CI run on PR #52:
#   - a double-quoted string inside an expression (only single quotes are legal)
#   - the literal expression delimiters in a comment; GitHub scans comments too,
#     and an empty pair is itself a syntax error
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$DOTFILES_DIR"

_fail=0
_skipped=""
_open='${'"{"          # built so this file never contains the literal delimiters
_close='}'"}"

_err() { printf '  ERROR: %s\n' "$1"; _fail=1; }
_ok()  { printf '  OK: %s\n' "$1"; }

shopt -s nullglob
_files=(.github/workflows/*.yml .github/workflows/*.yaml)
if [ ${#_files[@]} -eq 0 ]; then
    echo "no workflow files found - nothing to lint"
    exit 0
fi
printf 'linting %d workflow file(s)\n' "${#_files[@]}"

# 1. actionlint, when available. It catches expression syntax errors that a YAML
#    parser and the JSON schema both accept.
if command -v actionlint >/dev/null 2>&1; then
    # SC2016 fires on the repo's existing `su -c '...'` strings by design.
    if actionlint "${_files[@]}" 2>&1 | grep -v 'SC2016' | grep -q '^\.github'; then
        actionlint "${_files[@]}" 2>&1 | grep -v 'SC2016' | head -20
        _err "actionlint reported issues"
    else
        _ok "actionlint clean"
    fi
else
    _skipped="actionlint (not installed: https://github.com/rhysd/actionlint)"
fi

# 2. An empty expression pair anywhere, comments included.
if grep -n -F "${_open}${_close}" "${_files[@]}" 2>/dev/null \
        || grep -nE "\\$\{\{[[:space:]]*\}\}" "${_files[@]}" 2>/dev/null; then
    _err "empty expression pair - a syntax error even inside a comment"
else
    _ok "no empty expression pair"
fi

# 3. A double-quoted string literal inside an expression.
if grep -oE "\\$\{\{[^}]*\}\}" "${_files[@]}" 2>/dev/null | grep -q '"'; then
    grep -oE "\\$\{\{[^}]*\}\}" "${_files[@]}" 2>/dev/null | grep '"' | head -5
    _err "double-quoted string inside an expression - only single quotes are legal"
else
    _ok "expression string literals are single-quoted"
fi

echo
if [ -n "$_skipped" ]; then
    printf 'RESULT: %s, 1 check SKIPPED and not verified - %s\n' \
        "$([ "$_fail" -eq 0 ] && echo PASSED || echo FAILED)" "$_skipped"
else
    printf 'RESULT: %s (3 checks, none skipped)\n' "$([ "$_fail" -eq 0 ] && echo PASSED || echo FAILED)"
fi
exit "$_fail"
