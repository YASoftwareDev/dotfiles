#!/usr/bin/env bash
# Precondition checks — run before installing anything
# Exits non-zero with a clear message if requirements are not met.

run_checks() {
    log_step "Checking prerequisites"

    _check_os
    _check_transfer_tool
    _check_network
    _check_disk

    detect_sudo
    if ! $CAN_SUDO; then
        log_warn "Continuing without sudo — apt packages will be skipped."
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
            # Warn if Ubuntu < 20.04 (focal)
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
