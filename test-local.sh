#!/usr/bin/env bash
# Local matrix test runner — mirrors the GitHub Actions CI matrix.
#
# Usage:
#   bash test-local.sh                        # run all combinations
#   bash test-local.sh --ubuntu 22.04         # single Ubuntu version
#   bash test-local.sh --profile workstation  # single profile
#   bash test-local.sh --ubuntu 22.04 --profile docker  # single cell
#   bash test-local.sh --no-cache             # rebuild images from scratch
#   bash test-local.sh --help
#
# Requirements: docker must be installed and running.
# Log files: ./.test-results/<ubuntu>-<profile>.log

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
ALL_UBUNTU=(20.04 22.04 24.04)
ALL_PROFILES=(docker minimal workstation)
# nosudo is a special profile: it uses Dockerfile.nosudo and a non-root user.
ALL_NOSUDO_UBUNTU=(20.04 22.04 24.04)
FILTER_UBUNTU=()
FILTER_PROFILES=()
NO_CACHE=false
CLEAN=false
LOG_DIR="${DOTFILES_DIR}/.test-results"

# ── Colors ────────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# ── Argument parsing ──────────────────────────────────────────────────────────
usage() {
    cat <<EOF
Usage: bash test-local.sh [OPTIONS]

Options:
  --ubuntu VERSION      Test only this Ubuntu version (repeatable)
  --profile PROFILE     Test only this profile (repeatable)
  --no-cache            Pass --no-cache to docker build
  --clean               Remove ALL dotfiles-test:* images and dangling layers after
                        run (regardless of --ubuntu/--profile filters)
  --skip-nosudo         Skip the no-sudo matrix (Dockerfile.nosudo)
  --help                Show this help

Valid Ubuntu versions: ${ALL_UBUNTU[*]}
Valid profiles:        ${ALL_PROFILES[*]}  nosudo

Examples:
  bash test-local.sh
  bash test-local.sh --ubuntu 24.04 --profile minimal
  bash test-local.sh --ubuntu 22.04 --ubuntu 24.04 --profile docker
  bash test-local.sh --ubuntu 24.04 --profile nosudo
  bash test-local.sh --skip-nosudo
EOF
}

_validate_in() {
    local value="$1" label="$2"; shift 2
    local valid
    for valid in "$@"; do [[ "$value" == "$valid" ]] && return 0; done
    echo "Invalid ${label}: '${value}'. Valid: $*" >&2; exit 1
}

SKIP_NOSUDO=false
FILTER_NOSUDO=false  # true when user explicitly requests nosudo profile

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ubuntu)
            _validate_in "$2" "ubuntu version" "${ALL_UBUNTU[@]}"
            FILTER_UBUNTU+=("$2"); shift 2 ;;
        --profile)
            if [[ "$2" == "nosudo" ]]; then
                FILTER_NOSUDO=true; shift 2
            else
                _validate_in "$2" "profile" "${ALL_PROFILES[@]}"
                FILTER_PROFILES+=("$2"); shift 2
            fi ;;
        --no-cache)    NO_CACHE=true;    shift ;;
        --clean)       CLEAN=true;       shift ;;
        --skip-nosudo) SKIP_NOSUDO=true; shift ;;
        --help|-h)  usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

# NOTE: "${arr[@]:-default}" inside double quotes collapses to a single string
# element when arr is empty — use explicit length checks instead.
if [[ ${#FILTER_UBUNTU[@]} -eq 0 ]]; then
    UBUNTU_LIST=("${ALL_UBUNTU[@]}")
else
    UBUNTU_LIST=("${FILTER_UBUNTU[@]}")
fi
if [[ ${#FILTER_PROFILES[@]} -eq 0 ]]; then
    PROFILE_LIST=("${ALL_PROFILES[@]}")
else
    PROFILE_LIST=("${FILTER_PROFILES[@]}")
fi

# ── Helpers ───────────────────────────────────────────────────────────────────
_check_docker() {
    if ! command -v docker &>/dev/null; then
        echo -e "${RED}Error: docker not found. Install Docker and retry.${NC}" >&2
        exit 1
    fi
    if ! docker info &>/dev/null; then
        echo -e "${RED}Error: Docker daemon not running.${NC}" >&2
        exit 1
    fi
}

_tag() { echo "dotfiles-test:${1}-${2}"; }

_cleanup_images() {
    bash "${DOTFILES_DIR}/clean-test-images.sh" --force
}

_build() {
    local ubuntu="$1" profile="$2" tag logfile
    tag=$(_tag "$ubuntu" "$profile")
    logfile="${LOG_DIR}/${ubuntu}-${profile}.log"
    local -a cache_flag=()
    $NO_CACHE && cache_flag=(--no-cache)
    echo -e "  ${BLUE}→${NC} building ${BOLD}${tag}${NC} ..."
    if docker build \
        "${cache_flag[@]}" \
        --build-arg "UBUNTU=${ubuntu}" \
        --build-arg "PROFILE=${profile}" \
        -t "$tag" \
        "$DOTFILES_DIR" \
        >>"$logfile" 2>&1; then
        echo -e "  ${GREEN}✓${NC} build ok"
        return 0
    else
        echo -e "  ${RED}✗${NC} build FAILED  (see $logfile)"
        return 1
    fi
}

_run_step() {
    local tag="$1" label="$2" logfile="$3"
    shift 3
    echo -e "  ${BLUE}→${NC} ${label} ..."
    if docker run --rm \
        -e TERM=xterm-256color \
        -e POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true \
        "$tag" bash -c "$*" \
        >>"$logfile" 2>&1; then
        echo -e "  ${GREEN}✓${NC} ${label}"
        return 0
    else
        echo -e "  ${RED}✗${NC} ${label} FAILED  (see $logfile)"
        return 1
    fi
}

# ── Per-combination runner ────────────────────────────────────────────────────
# Returns: 0=pass, 1=fail
run_combination() {
    local ubuntu="$1" profile="$2"
    local tag logfile
    tag=$(_tag "$ubuntu" "$profile")
    logfile="${LOG_DIR}/${ubuntu}-${profile}.log"

    mkdir -p "$LOG_DIR"
    : >"$logfile"  # truncate

    echo ""
    echo -e "${BOLD}── Ubuntu ${ubuntu}  /  ${profile} ──${NC}"

    # 1. Build image (install.sh runs during docker build via Dockerfile RUN)
    _build "$ubuntu" "$profile" || return 1

    # 2. Idempotency — re-run install.sh inside built image
    _run_step "$tag" "idempotency (re-run install.sh)" "$logfile" \
        "cd /root/dotfiles && bash install.sh ${profile}" || return 1

    # 3. Test suite
    _run_step "$tag" "test.sh ${profile}" "$logfile" \
        "cd /root/dotfiles && bash test.sh ${profile}" || return 1

    # 4. update.sh
    _run_step "$tag" "update.sh" "$logfile" \
        "cd /root/dotfiles && bash update.sh" || return 1

    # 5. Test suite again after update
    _run_step "$tag" "test.sh after update" "$logfile" \
        "cd /root/dotfiles && bash test.sh ${profile}" || return 1

    return 0
}

# ── No-sudo runner (uses Dockerfile.nosudo, non-root user) ───────────────────
# Returns: 0=pass, 1=fail
_build_nosudo() {
    local ubuntu="$1" tag logfile
    tag=$(_tag "$ubuntu" "nosudo")
    logfile="${LOG_DIR}/${ubuntu}-nosudo.log"
    local -a cache_flag=()
    $NO_CACHE && cache_flag=(--no-cache)
    echo -e "  ${BLUE}→${NC} building ${BOLD}${tag}${NC} (Dockerfile.nosudo) ..."
    if docker build \
        "${cache_flag[@]}" \
        --build-arg "UBUNTU=${ubuntu}" \
        -f "${DOTFILES_DIR}/Dockerfile.nosudo" \
        -t "$tag" \
        "$DOTFILES_DIR" \
        >>"$logfile" 2>&1; then
        echo -e "  ${GREEN}✓${NC} build ok"
        return 0
    else
        echo -e "  ${RED}✗${NC} build FAILED  (see $logfile)"
        return 1
    fi
}

run_nosudo() {
    local ubuntu="$1"
    local tag logfile
    tag=$(_tag "$ubuntu" "nosudo")
    logfile="${LOG_DIR}/${ubuntu}-nosudo.log"

    mkdir -p "$LOG_DIR"
    : >"$logfile"  # truncate

    echo ""
    echo -e "${BOLD}── Ubuntu ${ubuntu}  /  nosudo ──${NC}"

    # 1. Build (install.sh runs as non-root user during docker build)
    _build_nosudo "$ubuntu" || return 1

    # 2. Test suite (run as the same non-root user)
    echo -e "  ${BLUE}→${NC} test.sh nosudo ..."
    if docker run --rm \
        -e TERM=xterm-256color \
        -e POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true \
        --user user \
        "$tag" bash -c \
        "export PATH=\"\$HOME/.local/bin:\$PATH\"; cd ~/dotfiles && bash test.sh nosudo" \
        >>"$logfile" 2>&1; then
        echo -e "  ${GREEN}✓${NC} test.sh nosudo"
    else
        echo -e "  ${RED}✗${NC} test.sh nosudo FAILED  (see $logfile)"
        return 1
    fi

    # 3. Idempotency — re-run install.sh as non-root user
    echo -e "  ${BLUE}→${NC} idempotency (re-run install.sh minimal) ..."
    if docker run --rm \
        -e TERM=xterm-256color \
        --user user \
        "$tag" bash -c \
        "export PATH=\"\$HOME/.local/bin:\$PATH\"; cd ~/dotfiles && bash install.sh minimal" \
        >>"$logfile" 2>&1; then
        echo -e "  ${GREEN}✓${NC} idempotency"
    else
        echo -e "  ${RED}✗${NC} idempotency FAILED  (see $logfile)"
        return 1
    fi

    return 0
}

# ── Main ──────────────────────────────────────────────────────────────────────
_check_docker

total=0
passed=0
failed=0
declare -a results=()

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════╗"
echo -e "║     YA Dotfiles — Local Matrix Tests     ║"
echo -e "╚══════════════════════════════════════════╝${NC}"
echo ""
# Determine which no-sudo Ubuntu versions to run
if $FILTER_NOSUDO; then
    # User explicitly requested nosudo — use the ubuntu filter (or all)
    if [[ ${#FILTER_UBUNTU[@]} -gt 0 ]]; then
        NOSUDO_LIST=("${FILTER_UBUNTU[@]}")
    else
        NOSUDO_LIST=("${ALL_NOSUDO_UBUNTU[@]}")
    fi
    # Remove regular profiles if user only asked for nosudo
    if [[ ${#FILTER_PROFILES[@]} -eq 0 ]]; then
        PROFILE_LIST=()
    fi
elif $SKIP_NOSUDO; then
    NOSUDO_LIST=()
else
    NOSUDO_LIST=("${ALL_NOSUDO_UBUNTU[@]}")
fi

nosudo_count=${#NOSUDO_LIST[@]}
regular_count=$(( ${#UBUNTU_LIST[@]} * ${#PROFILE_LIST[@]} ))

echo -e "  Ubuntu versions : ${UBUNTU_LIST[*]}"
echo -e "  Profiles        : ${PROFILE_LIST[*]}"
echo -e "  No-sudo Ubuntu  : ${NOSUDO_LIST[*]:-none}"
echo -e "  Combinations    : $((regular_count + nosudo_count))"
echo -e "  Logs            : ${LOG_DIR}/"

for ubuntu in "${UBUNTU_LIST[@]}"; do
    for profile in "${PROFILE_LIST[@]}"; do
        total=$((total + 1))
        if run_combination "$ubuntu" "$profile"; then
            passed=$((passed + 1))
            results+=("${GREEN}PASS${NC}  Ubuntu ${ubuntu}  /  ${profile}")
        else
            failed=$((failed + 1))
            results+=("${RED}FAIL${NC}  Ubuntu ${ubuntu}  /  ${profile}  →  ${LOG_DIR}/${ubuntu}-${profile}.log")
        fi
    done
done

for ubuntu in "${NOSUDO_LIST[@]}"; do
    total=$((total + 1))
    if run_nosudo "$ubuntu"; then
        passed=$((passed + 1))
        results+=("${GREEN}PASS${NC}  Ubuntu ${ubuntu}  /  nosudo")
    else
        failed=$((failed + 1))
        results+=("${RED}FAIL${NC}  Ubuntu ${ubuntu}  /  nosudo  →  ${LOG_DIR}/${ubuntu}-nosudo.log")
    fi
done

# ── Summary table ─────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Results ──────────────────────────────────────────${NC}"
for r in "${results[@]}"; do
    echo -e "  ${r}"
done
echo ""
echo -e "  ${GREEN}Passed: ${passed}/${total}${NC}"
if [ "$failed" -gt 0 ]; then
    echo -e "  ${RED}Failed: ${failed}/${total}${NC}"
    $CLEAN && _cleanup_images
    echo ""
    exit 1
fi
$CLEAN && _cleanup_images
echo ""
