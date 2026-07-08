#!/usr/bin/env bash
# Local matrix test runner - mirrors the GitHub Actions CI matrix.
#
# Usage:
#   bash ci-local.sh                        # run all combinations
#   bash ci-local.sh --ubuntu 22.04         # single Ubuntu version
#   bash ci-local.sh --profile workstation  # single profile
#   bash ci-local.sh --ubuntu 22.04 --profile docker  # single cell
#   bash ci-local.sh --no-cache             # rebuild images from scratch
#   bash ci-local.sh --help
#
# Requirements: docker must be installed and running.
# Log files: ./.test-results/<ubuntu>-<profile>.log

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Defaults ──────────────────────────────────────────────────────────────────
ALL_UBUNTU=(20.04 22.04 24.04)
ALL_PROFILES=(docker minimal workstation)
# nosudo variants use Dockerfile.nosudo with a non-root user.
# forced:    user HAS sudo but NOSUDO=1 overrides it  (tests the explicit override)
# auto:      user has NO sudo binary; detect_sudo() auto-detects CAN_SUDO=false
# nonsudoer: sudo binary present but user NOT in sudoers; detect_sudo() must
#            auto-detect CAN_SUDO=false via `sudo -n -v` (no override set)
# The nosudo matrix also covers the RHEL family (AlmaLinux) - there the
# binary-fetch path is the ONLY install path, sudo or not (no apt).
ALL_NOSUDO_UBUNTU=(20.04 22.04 24.04)
ALL_NOSUDO_ALMA=(9 10)
ALL_NOSUDO_VARIANTS=(forced auto nonsudoer)
FILTER_UBUNTU=()
FILTER_ALMA=()
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
Usage: bash ci-local.sh [OPTIONS]

Options:
  --ubuntu VERSION      Test only this Ubuntu version (repeatable)
  --alma VERSION        Test only this AlmaLinux version - nosudo cells only (repeatable)
  --profile PROFILE     Test only this profile (repeatable)
  --no-cache            Pass --no-cache to docker build
  --clean               Remove ALL dotfiles-test:* images and dangling layers after
                        run (regardless of --ubuntu/--profile filters)
  --skip-nosudo         Skip the no-sudo matrix (Dockerfile.nosudo)
  --help                Show this help

Valid Ubuntu versions : ${ALL_UBUNTU[*]}
Valid Alma versions   : ${ALL_NOSUDO_ALMA[*]}  (nosudo variants only - no apt profiles)
Valid profiles        : ${ALL_PROFILES[*]}
Valid nosudo variants : ${ALL_NOSUDO_VARIANTS[*]}  (or "nosudo" to run all)

  nosudo-forced     user HAS sudo but NOSUDO=1 overrides it
  nosudo-auto       user has NO sudo binary; detect_sudo() auto-detects
  nosudo-nonsudoer  sudo binary present but user NOT in sudoers; auto-detects

GitHub API rate limit: when GH_TOKEN is set (or \`gh auth token\` works), the
token is passed to builds/runs so API-based installers are not rate-limited.

Examples:
  bash ci-local.sh
  bash ci-local.sh --ubuntu 24.04 --profile minimal
  bash ci-local.sh --ubuntu 22.04 --ubuntu 24.04 --profile docker
  bash ci-local.sh --ubuntu 24.04 --profile nosudo             # all variants
  bash ci-local.sh --alma 9 --profile nosudo-auto              # AlmaLinux 9, one variant
  bash ci-local.sh --ubuntu 24.04 --profile nosudo-forced      # one variant
  bash ci-local.sh --ubuntu 24.04 --profile nosudo-nonsudoer   # one variant
  bash ci-local.sh --skip-nosudo
EOF
}

_validate_in() {
    local value="$1" label="$2"; shift 2
    local valid
    for valid in "$@"; do [[ "$value" == "$valid" ]] && return 0; done
    echo "Invalid ${label}: '${value}'. Valid: $*" >&2; exit 1
}

SKIP_NOSUDO=false
FILTER_NOSUDO=false        # true when user explicitly requests any nosudo variant
FILTER_NOSUDO_VARIANTS=()  # specific variants requested (empty = all)

while [[ $# -gt 0 ]]; do
    case "$1" in
        --ubuntu)
            _validate_in "$2" "ubuntu version" "${ALL_UBUNTU[@]}"
            FILTER_UBUNTU+=("$2"); shift 2 ;;
        --alma)
            _validate_in "$2" "alma version" "${ALL_NOSUDO_ALMA[@]}"
            FILTER_ALMA+=("$2"); shift 2 ;;
        --profile)
            case "$2" in
                nosudo)
                    # "nosudo" is shorthand for all variants
                    FILTER_NOSUDO=true; shift 2 ;;
                nosudo-forced|nosudo-auto|nosudo-nonsudoer)
                    FILTER_NOSUDO=true
                    FILTER_NOSUDO_VARIANTS+=("${2#nosudo-}"); shift 2 ;;
                *)
                    _validate_in "$2" "profile" "${ALL_PROFILES[@]}"
                    FILTER_PROFILES+=("$2"); shift 2 ;;
            esac ;;
        --no-cache)    NO_CACHE=true;    shift ;;
        --clean)       CLEAN=true;       shift ;;
        --skip-nosudo) SKIP_NOSUDO=true; shift ;;
        --help|-h)  usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

# NOTE: "${arr[@]:-default}" inside double quotes collapses to a single string
# element when arr is empty - use explicit length checks instead.
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

# ── GitHub API auth (optional) ────────────────────────────────────────────────
# Unauthenticated builds hit GitHub's 60-req/hr API cap: API-based installers
# (rg, fd, jq, zoxide, delta, eza) then fail with "could not find release URL -
# skipping" - a false failure. With a token, builds get a ~/.curlrc via BuildKit
# secret (never stored in image layers) and runs get it via GH_TOKEN env.
GH_TOKEN_VAL="${GH_TOKEN:-$(gh auth token 2>/dev/null || true)}"
GH_TOKEN_FILE=""
if [ -n "$GH_TOKEN_VAL" ]; then
    GH_TOKEN_FILE=$(mktemp)
    printf '%s' "$GH_TOKEN_VAL" > "$GH_TOKEN_FILE"
    chmod 600 "$GH_TOKEN_FILE"
    trap 'rm -f "$GH_TOKEN_FILE"' EXIT
fi
# Prepended to in-container commands: writes ~/.curlrc from the GH_TOKEN env
# var (single-quoted here - expands inside the container, not on the host).
_CURLRC_CMD='[ -n "${GH_TOKEN:-}" ] && printf "header = \"Authorization: Bearer %s\"\n" "$GH_TOKEN" > ~/.curlrc || true'

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
    # Optional leading flag: -u USER  (passed as --user USER to docker run)
    local run_user_flag=()
    if [[ "${1:-}" == "-u" ]]; then
        run_user_flag=(--user "$2"); shift 2
    fi
    local tag="$1" label="$2" logfile="$3"
    shift 3
    echo -e "  ${BLUE}→${NC} ${label} ..."
    if docker run --rm \
        "${run_user_flag[@]}" \
        -e TERM=xterm-256color \
        -e POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true \
        -e GH_TOKEN="${GH_TOKEN_VAL:-}" \
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

    # 2. Idempotency - re-run install.sh inside built image
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
# base_label: short tag/log identifier (e.g. "24.04", "alma9")
# base_image: docker image reference   (e.g. "ubuntu:24.04", "almalinux:9")
# variant: "forced"    (has sudo, NOSUDO=1 override)
#        | "auto"      (no sudo binary)
#        | "nonsudoer" (sudo binary present, user not in sudoers, no override)
# Returns: 0=pass, 1=fail
_build_nosudo() {
    local base_label="$1" base_image="$2" variant="$3" tag logfile
    tag=$(_tag "$base_label" "nosudo-${variant}")
    logfile="${LOG_DIR}/${base_label}-nosudo-${variant}.log"
    local -a cache_flag=() extra_args=() secret_flag=()
    $NO_CACHE && cache_flag=(--no-cache)
    [ -n "$GH_TOKEN_FILE" ] && secret_flag=(--secret "id=gh_token,src=${GH_TOKEN_FILE}")
    case "$variant" in
        forced)    extra_args=(--build-arg "GRANT_SUDO=true"  --build-arg "NOSUDO_INSTALL=1") ;;
        auto)      extra_args=(--build-arg "GRANT_SUDO=false" --build-arg "NOSUDO_INSTALL=") ;;
        nonsudoer) extra_args=(--build-arg "GRANT_SUDO=false" --build-arg "INSTALL_SUDO=true" --build-arg "NOSUDO_INSTALL=") ;;
    esac
    echo -e "  ${BLUE}→${NC} building ${BOLD}${tag}${NC} (Dockerfile.nosudo, base=${base_image}, variant=${variant}) ..."
    if docker build \
        "${cache_flag[@]}" \
        --build-arg "BASE=${base_image}" \
        "${extra_args[@]}" \
        "${secret_flag[@]}" \
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
    local base_label="$1" base_image="$2" variant="$3"
    local tag logfile install_cmd
    tag=$(_tag "$base_label" "nosudo-${variant}")
    logfile="${LOG_DIR}/${base_label}-nosudo-${variant}.log"

    # For idempotency re-run: nosudo-forced needs NOSUDO=1; nosudo-auto and
    # nosudo-nonsudoer rely on detect_sudo() reaching CAN_SUDO=false on its own
    # (no sudo binary / not in sudoers respectively), so no flag is needed.
    case "$variant" in
        forced)    install_cmd="NOSUDO=1 bash install.sh minimal" ;;
        auto)      install_cmd="bash install.sh minimal" ;;
        nonsudoer) install_cmd="bash install.sh minimal" ;;
    esac

    mkdir -p "$LOG_DIR"
    : >"$logfile"  # truncate

    echo ""
    echo -e "${BOLD}── ${base_image}  /  nosudo-${variant} ──${NC}"

    # 1. Build (install.sh runs as non-root user during docker build)
    _build_nosudo "$base_label" "$base_image" "$variant" || return 1

    # 2. Test suite
    _run_step -u user "$tag" "test.sh nosudo" "$logfile" \
        "export PATH=\"\$HOME/.local/bin:\$PATH\"; cd ~/dotfiles && bash test.sh nosudo" \
        || return 1

    # 3. Idempotency - re-run install.sh (must be a no-op)
    _run_step -u user "$tag" "idempotency (re-run install.sh minimal)" "$logfile" \
        "${_CURLRC_CMD}; export PATH=\"\$HOME/.local/bin:\$PATH\"; cd ~/dotfiles && ${install_cmd}" \
        || return 1

    # 4. update.sh
    _run_step -u user "$tag" "update.sh" "$logfile" \
        "${_CURLRC_CMD}; export PATH=\"\$HOME/.local/bin:\$PATH\"; cd ~/dotfiles && bash update.sh" \
        || return 1

    # 5. Re-validate after update
    _run_step -u user "$tag" "test.sh nosudo (after update)" "$logfile" \
        "export PATH=\"\$HOME/.local/bin:\$PATH\"; cd ~/dotfiles && bash test.sh nosudo" \
        || return 1

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
echo -e "║     YA Dotfiles - Local Matrix Tests     ║"
echo -e "╚══════════════════════════════════════════╝${NC}"
echo ""
# Determine which no-sudo bases (Ubuntu + AlmaLinux) to run.
# A --ubuntu filter without --alma limits nosudo to those Ubuntu versions (and
# vice versa) so a single-cell invocation never pulls in the other distro.
_resolve_nosudo_bases() {
    if [[ ${#FILTER_UBUNTU[@]} -gt 0 && ${#FILTER_ALMA[@]} -eq 0 ]]; then
        NOSUDO_LIST=("${FILTER_UBUNTU[@]}"); NOSUDO_ALMA_LIST=()
    elif [[ ${#FILTER_ALMA[@]} -gt 0 && ${#FILTER_UBUNTU[@]} -eq 0 ]]; then
        NOSUDO_LIST=(); NOSUDO_ALMA_LIST=("${FILTER_ALMA[@]}")
    elif [[ ${#FILTER_ALMA[@]} -gt 0 && ${#FILTER_UBUNTU[@]} -gt 0 ]]; then
        NOSUDO_LIST=("${FILTER_UBUNTU[@]}"); NOSUDO_ALMA_LIST=("${FILTER_ALMA[@]}")
    else
        NOSUDO_LIST=("${ALL_NOSUDO_UBUNTU[@]}"); NOSUDO_ALMA_LIST=("${ALL_NOSUDO_ALMA[@]}")
    fi
}
if $FILTER_NOSUDO; then
    # User explicitly requested nosudo
    _resolve_nosudo_bases
    # Remove regular profiles if user only asked for nosudo
    if [[ ${#FILTER_PROFILES[@]} -eq 0 ]]; then
        PROFILE_LIST=()
    fi
elif $SKIP_NOSUDO; then
    NOSUDO_LIST=(); NOSUDO_ALMA_LIST=()
else
    _resolve_nosudo_bases
fi

# Resolve which nosudo variants to run
if [[ ${#FILTER_NOSUDO_VARIANTS[@]} -gt 0 ]]; then
    NOSUDO_VARIANT_LIST=("${FILTER_NOSUDO_VARIANTS[@]}")
else
    NOSUDO_VARIANT_LIST=("${ALL_NOSUDO_VARIANTS[@]}")
fi

nosudo_count=$(( (${#NOSUDO_LIST[@]} + ${#NOSUDO_ALMA_LIST[@]}) * ${#NOSUDO_VARIANT_LIST[@]} ))
regular_count=$(( ${#UBUNTU_LIST[@]} * ${#PROFILE_LIST[@]} ))

echo -e "  Ubuntu versions  : ${UBUNTU_LIST[*]}"
echo -e "  Profiles         : ${PROFILE_LIST[*]:-none}"
echo -e "  No-sudo Ubuntu   : ${NOSUDO_LIST[*]:-none}"
echo -e "  No-sudo Alma     : ${NOSUDO_ALMA_LIST[*]:-none}"
echo -e "  No-sudo variants : ${NOSUDO_VARIANT_LIST[*]:-none}"
echo -e "  GitHub API auth  : $([ -n "$GH_TOKEN_VAL" ] && echo "token found" || echo "none (60 req/hr limit)")"
echo -e "  Combinations     : $((regular_count + nosudo_count))"
echo -e "  Logs             : ${LOG_DIR}/"

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
    for variant in "${NOSUDO_VARIANT_LIST[@]}"; do
        total=$((total + 1))
        if run_nosudo "$ubuntu" "ubuntu:${ubuntu}" "$variant"; then
            passed=$((passed + 1))
            results+=("${GREEN}PASS${NC}  Ubuntu ${ubuntu}  /  nosudo-${variant}")
        else
            failed=$((failed + 1))
            results+=("${RED}FAIL${NC}  Ubuntu ${ubuntu}  /  nosudo-${variant}  →  ${LOG_DIR}/${ubuntu}-nosudo-${variant}.log")
        fi
    done
done

for alma in "${NOSUDO_ALMA_LIST[@]}"; do
    for variant in "${NOSUDO_VARIANT_LIST[@]}"; do
        total=$((total + 1))
        if run_nosudo "alma${alma}" "almalinux:${alma}" "$variant"; then
            passed=$((passed + 1))
            results+=("${GREEN}PASS${NC}  AlmaLinux ${alma}  /  nosudo-${variant}")
        else
            failed=$((failed + 1))
            results+=("${RED}FAIL${NC}  AlmaLinux ${alma}  /  nosudo-${variant}  →  ${LOG_DIR}/alma${alma}-nosudo-${variant}.log")
        fi
    done
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
