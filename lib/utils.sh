#!/usr/bin/env bash
# Shared logging and helper utilities for dotfiles install

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

log_info()  { echo -e "  ${BLUE}→${NC} $*"; }
log_ok()    { echo -e "  ${GREEN}✓${NC} $*"; }
log_warn()  { echo -e "  ${YELLOW}!${NC} $*" >&2; }
log_error() { echo -e "  ${RED}✗${NC} $*" >&2; }
log_step()  { echo -e "\n${BOLD}── $* ──${NC}"; }
die()       { log_error "$*"; exit 1; }

# Check if a command exists
has() { command -v "$1" &>/dev/null; }

# Run apt-get quietly with noninteractive frontend
apt_install() {
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -yq "$@"
}

# Check if we can use sudo (sets globals SUDO, CAN_SUDO, SUDO_STATUS).
# Pure probe — no output, no sudo -v, never prompts interactively.
# SUDO_STATUS values: root | sudo_passwordless | sudo_password | nosudo
detect_sudo() {
    if [ -n "${NOSUDO:-}" ]; then
        SUDO=""
        CAN_SUDO=false
        SUDO_STATUS=nosudo
        export SUDO CAN_SUDO SUDO_STATUS
        return
    fi
    if [ "$(id -u)" -eq 0 ]; then
        SUDO=""
        CAN_SUDO=true
        SUDO_STATUS=root
    elif sudo -n true 2>/dev/null; then
        SUDO="sudo"
        CAN_SUDO=true
        SUDO_STATUS=sudo_passwordless
    elif command -v sudo &>/dev/null; then
        # sudo binary found but -n probe failed. Cannot distinguish "needs password"
        # from "not in sudoers" without prompting. CAN_SUDO=true is set optimistically;
        # the first $SUDO call will fail loudly if the user is not actually in sudoers.
        SUDO="sudo"
        CAN_SUDO=true
        SUDO_STATUS=sudo_password
    else
        SUDO=""
        CAN_SUDO=false
        SUDO_STATUS=nosudo
    fi
    export SUDO CAN_SUDO SUDO_STATUS
}

# Safe symlink: creates parent dir and force-overwrites existing link
symlink() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    ln -sf "$src" "$dst"
}

# Fetch latest release download URL from GitHub for a given asset pattern.
# Usage: _gh_latest_release OWNER/REPO PATTERN
_gh_latest_release() {
    local repo="$1" pattern="$2"
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local raw
    if has curl; then raw=$(curl -sfL "$api") || return 1
    else raw=$(wget -qO- "$api") || return 1; fi
    printf '%s\n' "$raw" \
        | grep -o '"browser_download_url": *"[^"]*'"${pattern}"'[^"]*"' \
        | grep -o 'https://[^"]*' \
        | head -1
}

# Fetch the latest release tag name from GitHub (e.g. "v1.2.3").
# Usage: _gh_latest_tag OWNER/REPO
_gh_latest_tag() {
    local repo="$1"
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local raw
    if has curl; then raw=$(curl -sfL "$api") || return 1
    else raw=$(wget -qO- "$api") || return 1; fi
    printf '%s\n' "$raw" \
        | grep -o '"tag_name": *"[^"]*"' \
        | grep -o '"[^"]*"$' \
        | tr -d '"' \
        | head -1
}

# Fetch the latest release tag without the GitHub API (avoids rate limits).
# Follows the /releases/latest HTTP redirect; curl reports the effective URL
# which contains the tag name. Falls back to the API method if redirect fails.
# Usage: tag=$(_gh_latest_tag_noapi OWNER/REPO)
_gh_latest_tag_noapi() {
    local repo="$1"
    local redirect_url="https://github.com/${repo}/releases/latest"
    local effective tag
    if has curl; then
        effective=$(curl -sfL -o /dev/null -w '%{url_effective}' "$redirect_url") || effective=""
        if [ -n "$effective" ]; then
            tag=$(echo "$effective" | sed 's|.*/tag/||')
            [ -n "$tag" ] && echo "$tag" && return 0
        fi
    fi
    # Fallback to JSON API (may be rate-limited but try anyway)
    _gh_latest_tag "$repo"
}

# Fetch latest release tag AND a download URL in a single API call.
# On success, prints "TAG URL" on one line (URL may be empty if pattern unmatched).
# Usage: read -r tag url < <(_gh_release_info OWNER/REPO PATTERN)
_gh_release_info() {
    local repo="$1" pattern="$2"
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local raw
    if has curl; then raw=$(curl -sfL "$api") || return 1
    else raw=$(wget -qO- "$api") || return 1; fi
    local tag url
    tag=$(printf '%s\n' "$raw" \
        | grep -o '"tag_name": *"[^"]*"' \
        | grep -o '"[^"]*"$' \
        | tr -d '"' \
        | head -1)
    url=$(printf '%s\n' "$raw" \
        | grep -o '"browser_download_url": *"[^"]*'"${pattern}"'[^"]*"' \
        | grep -o 'https://[^"]*' \
        | head -1)
    [ -n "$tag" ] && printf '%s %s\n' "$tag" "${url:-}"
}

# ── Precondition checks ────────────────────────────────────────────────────────

run_checks() {
    log_step "Checking prerequisites"
    _check_os
    _check_transfer_tool
    _check_network
    _check_disk
    detect_sudo
    case "$SUDO_STATUS" in
        root)
            log_ok "Running as root — system packages will be installed directly" ;;
        sudo_passwordless)
            log_ok "sudo available (passwordless) — system packages will be installed via apt" ;;
        sudo_password)
            log_info "sudo available — system packages will be installed via apt"
            log_warn "sudo requires a password — you will be prompted when apt runs" ;;
        nosudo)
            if [ -n "${NOSUDO:-}" ]; then
                log_info "NOSUDO=1 set — running in user-local mode (sudo disabled)"
            else
                log_warn "No sudo — apt skipped; tools will be fetched as local binaries into ~/.local/bin"
            fi ;;
    esac
    if $CAN_SUDO && [ -n "${PROFILE:-}" ]; then
        case "$PROFILE" in
            minimal)
                log_info "sudo will be used for: apt packages, chsh/usermod (default shell)" ;;
            workstation)
                log_info "sudo will be used for: apt packages, neovim install to /usr/local/, chsh/usermod (default shell)" ;;
            docker)
                log_info "sudo will be used for: apt packages" ;;
        esac
    fi
    log_ok "All checks passed"
}

_check_os() {
    if [ ! -f /etc/os-release ]; then
        log_warn "Cannot detect OS. Proceeding anyway (non-Ubuntu systems may have issues)."
        return
    fi
    # shellcheck source=/dev/null
    . /etc/os-release
    case "$ID" in
        ubuntu | debian | linuxmint | pop)
            local version_id="${VERSION_ID:-0}"
            if [ "$ID" = "ubuntu" ] && awk "BEGIN{exit !($version_id < 20.04)}"; then
                log_warn "Ubuntu $VERSION_ID detected. Recommended: 20.04+. Some packages may not be available."
            else
                log_ok "OS: $PRETTY_NAME"
            fi
            ;;
        *)
            log_warn "OS '$ID' is not Ubuntu/Debian. Package installation may fail — proceeding anyway."
            ;;
    esac
}

_check_network() {
    if has curl; then
        curl -sSf --max-time 5 https://github.com &>/dev/null && log_ok "Network: reachable" && return
    elif has wget; then
        wget -q --spider --timeout=5 https://github.com &>/dev/null && log_ok "Network: reachable" && return
    fi
    die "No internet access (couldn't reach github.com). Check your connection and retry."
}

_check_disk() {
    local required_mb=2048
    local available_mb
    available_mb=$(df -m "$HOME" | awk 'NR==2{print $4}')
    if [ "$available_mb" -lt "$required_mb" ]; then
        die "Need at least ${required_mb} MB free in \$HOME (have ${available_mb} MB). Free up space and retry."
    fi
    log_ok "Disk: ${available_mb} MB free"
}

_check_transfer_tool() {
    if has curl || has wget; then
        log_ok "Transfer tool: $(has curl && echo curl || echo wget)"
    else
        die "Neither curl nor wget found. Install one and retry."
    fi
}

# ── Binary download and update helpers ────────────────────────────────────────

# Extract a version string from a command's --version output.
# Usage: ver=$(_cmd_version COMMAND [ARGS...])
_cmd_version() {
    "$@" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}

# Download a tarball from URL and extract a single binary by name.
# Auto-detects .tar.gz vs .tar.xz from the URL.
# Usage: _download_tar_bin URL BINARY_NAME DEST
_download_tar_bin() {
    local url="$1" binname="$2" dest="$3"
    mkdir -p "$(dirname "$dest")"
    local tmp
    tmp=$(mktemp -d)
    local -a tar_flags
    case "$url" in
        *.tar.xz|*.txz) tar_flags=(-xJ) ;;
        *)               tar_flags=(-xz) ;;
    esac
    if has curl; then curl -sfL "$url" | tar "${tar_flags[@]}" -C "$tmp"
    else wget -qO- "$url" | tar "${tar_flags[@]}" -C "$tmp"; fi
    local found
    found=$(find "$tmp" -name "$binname" -type f | head -1)
    if [ -z "$found" ]; then rm -rf "$tmp"; return 1; fi
    mv "$found" "$dest"
    chmod +x "$dest"
    rm -rf "$tmp"
}

# Verify the installed binary at DEST is what the shell will actually resolve.
# Usage: _verify_dest BINARY_NAME DEST
_verify_dest() {
    local binname="$1" dest="$2"
    local resolved
    resolved=$(command -v "$binname" 2>/dev/null || true)
    if [ -z "$resolved" ]; then
        log_warn "$binname: installed to $dest but not found on PATH — add $(dirname "$dest") to PATH"
    elif [ "$resolved" != "$dest" ]; then
        log_warn "$binname: installed to $dest but shell resolves to $resolved — $(dirname "$dest") must come before $(dirname "$resolved") in PATH"
    fi
}

# Print current vs latest version comparison (check mode).
# Usage: _report_version NAME CURRENT LATEST
_report_version() {
    local name="$1" current="${2:-none}" latest="${3:-unknown}"
    local cur_v="${current#v}" lat_v="${latest#v}"
    if [ -z "$lat_v" ] || [ "$lat_v" = "unknown" ]; then
        log_warn "$name: installed=$current  latest=unknown (fetch failed)"
    elif [ "$cur_v" = "$lat_v" ]; then
        log_ok "$name: $current (up to date)"
    else
        log_info "$name: installed=$current  latest=$latest"
    fi
}

# Fetch upstream and report pending commits (check mode for git-managed dirs).
# Usage: _check_git_updates NAME PATH
_check_git_updates() {
    local name="$1" path="$2"
    if [ ! -d "$path" ]; then
        log_warn "$name not found at $path — skipping"
        return
    fi
    git -C "$path" fetch -q 2>/dev/null || { log_warn "$name: fetch failed"; return; }
    local count
    count=$(git -C "$path" rev-list "HEAD..@{u}" --count 2>/dev/null || echo "?")
    if [ "$count" = "?" ]; then
        log_warn "$name: could not determine upstream status (no tracking branch?)"
    elif [ "$count" = "0" ]; then
        log_ok "$name: up to date"
    else
        log_info "$name: $count commit(s) behind upstream"
    fi
}

# Resolve install destination: use current binary location, but never /usr/*.
# Usage: dest=$(_resolve_dest BINARY_NAME FALLBACK_DEST)
_resolve_dest() {
    local binname="$1" fallback="$2"
    local dest
    dest=$(command -v "$binname" 2>/dev/null || echo "$fallback")
    [[ "$dest" == /usr/* ]] && dest="$fallback"
    echo "$dest"
}

# Handle check-or-update for a standard single-binary GitHub release (tar.gz/xz).
# Usage: _gh_update_binary NAME REPO ASSET_PATTERN BINARY DEST
# Requires: CHECK_ONLY global to be set
_gh_update_binary() {
    local name="$1" repo="$2" pattern="$3" binname="$4" dest="$5"
    if $CHECK_ONLY; then
        local current="" latest=""
        current=$(_cmd_version "$binname" --version) || current=""
        latest=$(_gh_latest_tag "$repo") || latest=""
        _report_version "$name" "$current" "${latest:-unknown}"
    else
        local url="" ver=""
        url=$(_gh_latest_release "$repo" "$pattern") || url=""
        if [ -n "$url" ]; then
            _download_tar_bin "$url" "$binname" "$dest" \
                || { log_warn "$name: failed to extract binary from archive — skipping"; return 1; }
            ver=$(_cmd_version "$dest" --version) || ver="?"
            log_ok "$name updated → $dest ($ver)"
            _verify_dest "$binname" "$dest"
        else
            log_warn "$name: could not fetch release URL — skipping"
            return 1
        fi
    fi
}

# Update a git-managed plugin directory.
# Usage: _update_plugin NAME PATH
_update_plugin() {
    local name="$1" path="$2"
    if [ -d "$path" ]; then
        if git -C "$path" pull --quiet --rebase; then
            log_ok "$name updated"
        else
            log_warn "$name: git pull failed — skipping (local changes or network issue?)"
        fi
    else
        log_warn "$name not found at $path — skipping"
    fi
}
