#!/usr/bin/env bash
# Base system packages - requires apt (Ubuntu/Debian)
# Idempotent: apt handles "already installed" gracefully
# When CAN_APT=false (no sudo, or a non-apt distro such as AlmaLinux), apt
# steps are skipped and tools are fetched as pre-built binaries into
# ~/.local/bin instead.

install_base() {
    log_step "Base packages"
    mkdir -p ~/.local/bin

    if $CAN_APT; then
        local -a _pkgs=(
            locales
            git curl wget
            zsh tmux neovim
            jq
            man-db gnupg
            python3 python3-venv
            ripgrep fd-find tig
            parallel shellcheck
        )
        log_info "Installing via apt: ${_pkgs[*]} (versions resolved by apt)"
        $SUDO apt-get -yq update
        apt_install "${_pkgs[@]}"

        # Ensure en_US.UTF-8 locale is generated - without this, Perl (and tools
        # that shell out to it) will warn whenever LANG=en_US.UTF-8 is set but the
        # locale data isn't present (e.g. on fresh minimal Ubuntu installs).
        if ! locale -a 2>/dev/null | grep -q 'en_US.utf8'; then
            log_info "Generating locale: en_US.UTF-8"
            $SUDO locale-gen en_US.UTF-8
        fi

        # fd is installed as 'fdfind' on Debian/Ubuntu - add a shim if fd is missing
        if ! has fd && has fdfind; then
            ln -sf "$(command -v fdfind)" ~/.local/bin/fd
            log_ok "Created fd → fdfind shim in ~/.local/bin"
        fi
    else
        if $CAN_SUDO; then
            log_warn "No apt on this system - skipping system packages; fetching tools as local binaries"
        else
            log_warn "No sudo - skipping system packages; fetching tools as local binaries"
        fi
        local _hint; _hint=$(_pkg_install_hint)
        for tool in git zsh tmux python3; do
            has "$tool" || log_warn "$tool not found - install it: ${_hint} $tool"
        done
        _install_ripgrep
        _install_fd
        _install_jq
    fi

    _install_fzf
    _install_zoxide
    _install_delta
    _install_eza
    _install_yazi

    if ! $CAN_APT; then
        log_warn "Binaries installed to ~/.local/bin - ensure it is on your PATH:"
        log_warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi

    log_ok "Base packages installed"
}

install_base_docker() {
    log_step "Base packages (docker mode)"
    if ! $CAN_APT; then
        log_warn "Skipping system packages (no sudo or no apt)"
        return
    fi

    local -a _pkgs=(
        locales git curl wget
        zsh tmux neovim
        jq ripgrep fd-find shellcheck
    )
    log_info "Installing via apt: ${_pkgs[*]} (versions resolved by apt)"
    $SUDO apt-get -yq update
    apt_install "${_pkgs[@]}"
    log_info "Generating locale: en_US.UTF-8"
    $SUDO locale-gen en_US.UTF-8
    $SUDO update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

    if ! has fd && has fdfind; then
        mkdir -p ~/.local/bin
        ln -sf "$(command -v fdfind)" ~/.local/bin/fd
    fi

    _install_fzf
    _install_zoxide
    _install_delta

    log_ok "Base packages installed (docker)"
}

# ── Per-tool installers with apt-first / fallback strategy ────────────────────

# Debian/Ubuntu architecture string (amd64, arm64, armhf, ...)
_deb_arch() {
    dpkg --print-architecture 2>/dev/null || case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "armhf" ;;
        *)       uname -m ;;
    esac
}

# zoxide: apt on Ubuntu 24.04 (≥0.8); GitHub binary on 20.04/22.04
# The 22.04 apt package is 0.4.3 - too old; our .zshrc uses `zi` (needs ≥0.8).
_install_zoxide() {
    if has zoxide; then
        log_ok "zoxide already installed - skipping"
        return
    fi

    # Probe apt: only use it if the available version is ≥ 0.8
    local apt_ver
    apt_ver=$(apt-cache show zoxide 2>/dev/null | grep '^Version:' \
              | grep -oE '[0-9]+\.[0-9]+' | head -1) || true
    local minor=0
    [ -n "$apt_ver" ] && minor=$(echo "$apt_ver" | cut -d. -f2)

    # major is always 0 for current zoxide; treat major>0 as always acceptable
    local major=0
    [ -n "$apt_ver" ] && major=$(echo "$apt_ver" | cut -d. -f1)

    if $CAN_APT && { [ "$major" -gt 0 ] || [ "$minor" -ge 8 ]; }; then
        log_info "zoxide: installing via apt (version ≥ 0.8 available) → system"
        apt_install zoxide
        return
    fi

    log_step "zoxide (GitHub binary)"
    local arch; arch=$(uname -m)
    local zoxide_arch
    case "$arch" in
        x86_64)  zoxide_arch="x86_64-unknown-linux-musl" ;;
        aarch64) zoxide_arch="aarch64-unknown-linux-musl" ;;
        *)
            log_warn "zoxide: unsupported arch $arch - skipping"
            return
            ;;
    esac

    # Use _gh_release_info to look up the exact asset URL - avoids fragile manual
    # construction that could break if zoxide renames assets between releases.
    local tag="" url=""
    read -r tag url < <(_gh_release_info "ajeetdsouza/zoxide" "${zoxide_arch}.tar.gz") || true

    if [ -z "$url" ]; then
        if $CAN_APT && [ -n "$apt_ver" ]; then
            log_warn "zoxide: could not determine latest version; falling back to apt $apt_ver"
            log_warn "zoxide: apt version <0.8 - 'zi' alias requires ≥0.8; run update.sh to upgrade"
            apt_install zoxide
            return
        fi
        log_warn "zoxide: could not determine latest version - skipping"
        return
    fi

    log_info "zoxide: installing $tag → ~/.local/bin/zoxide"
    if _download_tar_bin "$url" "zoxide" ~/.local/bin/zoxide; then
        log_ok "zoxide installed → ~/.local/bin ($(~/.local/bin/zoxide --version 2>/dev/null))"
        return
    fi

    # GitHub download failed (e.g. rate-limited in local Docker builds)
    if $CAN_APT && [ -n "$apt_ver" ]; then
        log_warn "zoxide: GitHub download failed; falling back to apt $apt_ver"
        log_warn "zoxide: apt version <0.8 - 'zi' alias requires ≥0.8; run update.sh to upgrade"
        apt_install zoxide
        return
    fi

    log_warn "zoxide: GitHub download failed and no apt package available - skipping"
}

# git-delta: apt on Ubuntu 24.04+; GitHub .deb on 20.04/22.04 with sudo,
# or musl tarball when no sudo is available.
# The .deb asset name has changed between releases (e.g. git-delta -> git-delta-musl),
# so we look up the actual URL via the API rather than constructing it.
_install_delta() {
    if has delta; then
        log_ok "git-delta already installed - skipping"
        return
    fi

    if $CAN_APT && apt-cache show git-delta &>/dev/null 2>&1; then
        apt_install git-delta
        return
    fi

    if $CAN_APT; then
        log_step "git-delta (GitHub .deb)"
        local arch; arch="$(_deb_arch)"
        local tag="" url=""
        # Use _gh_release_info to get both tag and exact .deb URL in one API call -
        # avoids brittle filename construction that breaks when asset names change.
        read -r tag url < <(_gh_release_info "dandavison/delta" "${arch}.deb") || true
        local ver="${tag#v}"
        if [ -z "$url" ]; then
            log_warn "git-delta: could not find .deb release URL - skipping"
            return
        fi
        local deb="${url##*/}"
        log_info "git-delta: installing ${ver:-unknown} → system (via .deb)"
        local tmp; tmp="$(mktemp -d)"
        # shellcheck disable=SC2064
        trap "rm -rf '$tmp'" RETURN
        if has curl; then
            curl -sfLo "$tmp/$deb" "$url" || { log_warn "git-delta: download failed - skipping"; return; }
        else
            wget -qO "$tmp/$deb" "$url"   || { log_warn "git-delta: download failed - skipping"; return; }
        fi
        $SUDO dpkg -i "$tmp/$deb"
        log_ok "git-delta ${ver} installed → $(command -v delta 2>/dev/null || echo 'system')"
    else
        log_step "git-delta (GitHub binary)"
        local arch; arch=$(uname -m)
        local delta_arch
        case "$arch" in
            x86_64)  delta_arch="x86_64-unknown-linux-musl" ;;
            aarch64) delta_arch="aarch64-unknown-linux-gnu"  ;;
            *)
                log_warn "git-delta: unsupported arch $arch - skipping"
                return
                ;;
        esac
        local tag="" url=""
        # Use _gh_release_info to get the actual asset URL - never construct it
        # manually; delta asset names have changed between releases.
        read -r tag url < <(_gh_release_info "dandavison/delta" "${delta_arch}.tar.gz") || true
        local ver="${tag#v}"
        if [ -z "$url" ]; then
            log_warn "git-delta: could not find release URL - skipping"
            return
        fi
        log_info "git-delta: installing ${ver:-unknown} → ~/.local/bin/delta"
        if _download_tar_bin "$url" "delta" ~/.local/bin/delta; then
            log_ok "git-delta installed → ~/.local/bin/delta ($(~/.local/bin/delta --version 2>/dev/null))"
        else
            log_warn "git-delta: download failed - skipping"
        fi
    fi
}

# eza: apt on Ubuntu 24.04+; official PPA on 20.04/22.04 with sudo,
# or musl tarball when no sudo is available.
_install_eza() {
    if has eza; then
        log_ok "eza already installed - skipping"
        return
    fi

    if $CAN_APT && apt-cache show eza &>/dev/null 2>&1; then
        log_info "eza: installing via apt → system"
        apt_install eza
        return
    fi

    if $CAN_APT; then
        log_step "eza (official PPA)"
        log_info "eza: installing latest → system (via PPA)"
        apt_install gpg  # needed for dearmor; may already be present
        $SUDO mkdir -p /etc/apt/keyrings
        if has curl; then
            curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | $SUDO gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
                || { log_warn "eza: failed to add PPA signing key - skipping"; return; }
        else
            wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | $SUDO gpg --dearmor -o /etc/apt/keyrings/gierens.gpg \
                || { log_warn "eza: failed to add PPA signing key - skipping"; return; }
        fi
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
            | $SUDO tee /etc/apt/sources.list.d/gierens.list > /dev/null
        $SUDO chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        $SUDO apt-get update -yq
        apt_install eza
        log_ok "eza installed via PPA ($(eza --version 2>/dev/null | head -1))"
    else
        log_step "eza (GitHub binary)"
        local arch; arch=$(uname -m)
        local eza_arch
        case "$arch" in
            x86_64)  eza_arch="x86_64-unknown-linux-musl" ;;
            aarch64) eza_arch="aarch64-unknown-linux-musl" ;;
            *)
                log_warn "eza: unsupported arch $arch - skipping"
                return
                ;;
        esac
        local tag="" url=""
        # Use _gh_release_info to get the verified asset URL - avoids fragile manual
        # construction that could break if eza renames assets between releases.
        read -r tag url < <(_gh_release_info "eza-community/eza" "eza_${eza_arch}.tar.gz") || true
        if [ -z "$url" ]; then
            log_warn "eza: could not find release URL - skipping"
            return
        fi
        log_info "eza: installing ${tag:-unknown} → ~/.local/bin/eza"
        if _download_tar_bin "$url" "eza" ~/.local/bin/eza; then
            log_ok "eza installed → ~/.local/bin/eza ($(~/.local/bin/eza --version 2>/dev/null | head -1))"
        else
            log_warn "eza: download failed - skipping"
        fi
    fi
}

# yazi: not in apt - always a GitHub binary release. Ships a .zip (not a tarball)
# containing both the `yazi` TUI and its `ya` CLI companion, so it needs a custom
# installer rather than _download_tar_bin. musl build -> runs on any glibc version.
_install_yazi() {
    log_step "yazi"
    if has yazi; then
        log_ok "yazi already installed - skipping"
        return
    fi

    local arch; arch=$(uname -m)
    local yazi_arch
    case "$arch" in
        x86_64)  yazi_arch="x86_64-unknown-linux-musl"  ;;
        aarch64) yazi_arch="aarch64-unknown-linux-musl" ;;
        *)
            log_warn "yazi: unsupported arch $arch - skipping"
            return
            ;;
    esac

    # yazi asset names carry no version (e.g. yazi-x86_64-unknown-linux-musl.zip),
    # so the latest/download URL is stable - no GitHub API call needed (avoids
    # rate limits), same approach as uv and cheat.
    local url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${yazi_arch}.zip"

    log_info "yazi: installing latest → ~/.local/bin/{yazi,ya}"
    mkdir -p ~/.local/bin
    local tmp
    tmp=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    local zip="$tmp/yazi.zip"
    local download_ok=true
    if has curl; then curl -sfL "$url" -o "$zip" || download_ok=false
    else wget -qO "$zip" "$url" || download_ok=false; fi
    if ! $download_ok; then
        log_warn "yazi: download failed - skipping (network issue?)"
        return
    fi

    # Extract - prefer unzip, fall back to python3's zipfile module (python3 is a
    # base dependency, so this works even where unzip is absent, e.g. no-sudo).
    if has unzip; then
        unzip -qo "$zip" -d "$tmp" || { log_warn "yazi: unzip failed - skipping"; return; }
    elif has python3; then
        python3 -m zipfile -e "$zip" "$tmp" || { log_warn "yazi: extraction failed - skipping"; return; }
    else
        log_warn "yazi: no unzip or python3 available to extract archive - skipping"
        return
    fi

    local b found
    for b in yazi ya; do
        found=$(find "$tmp" -name "$b" -type f | head -1)
        if [ -n "$found" ]; then
            mv "$found" ~/.local/bin/"$b"
            chmod +x ~/.local/bin/"$b"
        fi
    done

    if [ ! -x ~/.local/bin/yazi ]; then
        log_warn "yazi: binary not found in archive - archive structure may have changed"
        return
    fi
    log_ok "yazi installed → ~/.local/bin/yazi ($(~/.local/bin/yazi --version 2>/dev/null | head -1))"
}

# ripgrep: GitHub tarball - binary is 'rg'
_install_ripgrep() {
    if has rg; then
        log_ok "ripgrep already installed - skipping"
        return
    fi
    log_step "ripgrep (GitHub binary)"
    local arch; arch=$(uname -m)
    local rg_arch
    case "$arch" in
        x86_64)  rg_arch="x86_64-unknown-linux-musl" ;;
        aarch64) rg_arch="aarch64-unknown-linux-gnu"  ;;
        *)
            log_warn "ripgrep: unsupported arch $arch - skipping"
            return
            ;;
    esac
    local tag="" url=""
    read -r tag url < <(_gh_release_info "BurntSushi/ripgrep" "${rg_arch}.tar.gz") || true
    if [ -z "$url" ]; then
        log_warn "ripgrep: could not find release URL - skipping"
        return
    fi
    log_info "ripgrep: installing ${tag:-unknown} → ~/.local/bin/rg"
    if _download_tar_bin "$url" "rg" ~/.local/bin/rg; then
        log_ok "ripgrep installed → ~/.local/bin/rg ($(~/.local/bin/rg --version 2>/dev/null | head -1))"
    else
        log_warn "ripgrep: download failed - skipping"
    fi
}

# fd: GitHub tarball - binary is 'fd'
_install_fd() {
    if has fd || has fdfind; then
        log_ok "fd already installed - skipping"
        return
    fi
    log_step "fd (GitHub binary)"
    local arch; arch=$(uname -m)
    local fd_arch
    case "$arch" in
        x86_64)  fd_arch="x86_64-unknown-linux-musl" ;;
        aarch64) fd_arch="aarch64-unknown-linux-gnu"  ;;
        *)
            log_warn "fd: unsupported arch $arch - skipping"
            return
            ;;
    esac
    local tag="" url=""
    read -r tag url < <(_gh_release_info "sharkdp/fd" "${fd_arch}.tar.gz") || true
    if [ -z "$url" ]; then
        log_warn "fd: could not find release URL - skipping"
        return
    fi
    log_info "fd: installing ${tag:-unknown} → ~/.local/bin/fd"
    if _download_tar_bin "$url" "fd" ~/.local/bin/fd; then
        log_ok "fd installed → ~/.local/bin/fd ($(~/.local/bin/fd --version 2>/dev/null))"
    else
        log_warn "fd: download failed - skipping"
    fi
}

# jq: GitHub single-binary release
_install_jq() {
    if has jq; then
        log_ok "jq already installed - skipping"
        return
    fi
    log_step "jq (GitHub binary)"
    local arch; arch=$(uname -m)
    local jq_arch
    case "$arch" in
        x86_64)  jq_arch="amd64" ;;
        aarch64) jq_arch="arm64" ;;
        *)
            log_warn "jq: unsupported arch $arch - skipping"
            return
            ;;
    esac
    local tag="" url=""
    # Use _gh_release_info to get the verified asset URL - avoids fragile manual
    # construction that could break if jq renames assets between releases.
    read -r tag url < <(_gh_release_info "jqlang/jq" "jq-linux-${jq_arch}") || true
    if [ -z "$url" ]; then
        log_warn "jq: could not find release URL - skipping"
        return
    fi
    log_info "jq: installing ${tag:-unknown} → ~/.local/bin/jq"
    local ok=true
    if has curl; then
        curl -sfLo ~/.local/bin/jq "$url" || ok=false
    else
        wget -qO ~/.local/bin/jq "$url" || ok=false
    fi
    if $ok; then
        chmod +x ~/.local/bin/jq
        log_ok "jq installed → ~/.local/bin/jq ($(~/.local/bin/jq --version 2>/dev/null))"
    else
        log_warn "jq: download failed - skipping"
        rm -f ~/.local/bin/jq
    fi
}

# fzf: install via git clone so shell integration (~/.fzf.zsh) is generated
# automatically by the installer. The ~/.local/bin/fzf symlink is what wins
# PATH lookup over any older system fzf at /usr/local/bin or /usr/bin - and
# ~/.fzf.zsh's `source <(fzf --zsh)` (modern fzf integration style) needs the
# new fzf to win, otherwise shell startup errors with "unknown option: --zsh".
# Always reconcile the symlink, even when the clone already exists, so re-runs
# over partial state self-heal. Also regenerate ~/.fzf.zsh whenever it is
# missing - without it, .zshrc's `[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh`
# silently no-ops and Ctrl+R is not bound to fzf history search.
_install_fzf() {
    if [ ! -d ~/.fzf ]; then
        log_step "fzf (git clone)"
        log_info "fzf: installing latest → ~/.fzf/"
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf --quiet
        ~/.fzf/install --no-update-rc --key-bindings --completion
    elif [ ! -f ~/.fzf.zsh ]; then
        log_step "fzf (regenerate shell integration)"
        log_info "fzf: ~/.fzf.zsh missing - regenerating"
        ~/.fzf/install --no-update-rc --key-bindings --completion
    else
        log_ok "fzf already installed - skipping clone"
    fi
    mkdir -p ~/.local/bin
    ln -sf ~/.fzf/bin/fzf ~/.local/bin/fzf
}
