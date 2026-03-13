#!/usr/bin/env bash
# Base system packages — requires apt (Ubuntu/Debian)
# Idempotent: apt handles "already installed" gracefully
# When CAN_SUDO=false, apt steps are skipped and tools are fetched as
# pre-built binaries into ~/.local/bin instead.

install_base() {
    log_step "Base packages"
    mkdir -p ~/.local/bin

    if $CAN_SUDO; then
        local -a _pkgs=(
            git curl wget
            zsh tmux neovim
            ranger jq
            man-db gnupg
            python3 python3-venv
            ripgrep fd-find tig
            parallel shellcheck
        )
        log_info "Installing via apt: ${_pkgs[*]} (versions resolved by apt)"
        $SUDO apt-get -yq update
        apt_install "${_pkgs[@]}"

        # fd is installed as 'fdfind' on Debian/Ubuntu — add a shim if fd is missing
        if ! has fd && has fdfind; then
            ln -sf "$(command -v fdfind)" ~/.local/bin/fd
            log_ok "Created fd → fdfind shim in ~/.local/bin"
        fi
    else
        log_warn "No sudo — skipping apt; fetching available tools as local binaries"
        for tool in git zsh tmux python3; do
            has "$tool" || log_warn "$tool not found — install via your system package manager"
        done
        _install_ripgrep
        _install_fd
        _install_jq
    fi

    _install_fzf
    _install_zoxide
    _install_delta
    _install_eza

    if ! $CAN_SUDO; then
        log_warn "Binaries installed to ~/.local/bin — ensure it is on your PATH:"
        log_warn "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi

    log_ok "Base packages installed"
}

install_base_docker() {
    log_step "Base packages (docker mode)"
    if ! $CAN_SUDO; then
        log_warn "Skipping system packages (no sudo)"
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

# Debian/Ubuntu architecture string (amd64, arm64, armhf, …)
_deb_arch() {
    dpkg --print-architecture 2>/dev/null || case "$(uname -m)" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        armv7l)  echo "armhf" ;;
        *)       uname -m ;;
    esac
}

# zoxide: apt on Ubuntu 24.04 (≥0.8); GitHub binary on 20.04/22.04
# The 22.04 apt package is 0.4.3 — too old; our .zshrc uses `zi` (needs ≥0.8).
_install_zoxide() {
    if has zoxide; then
        log_ok "zoxide already installed — skipping"
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

    if $CAN_SUDO && { [ "$major" -gt 0 ] || [ "$minor" -ge 8 ]; }; then
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
            log_warn "zoxide: unsupported arch $arch — skipping"
            return
            ;;
    esac

    # Resolve download URL via redirect (no GitHub API rate limits)
    local url="" tag ver
    tag=$(_gh_latest_tag_noapi "ajeetdsouza/zoxide") || tag=""
    if [ -n "$tag" ]; then
        ver="${tag#v}"
        url="https://github.com/ajeetdsouza/zoxide/releases/download/${tag}/zoxide-${ver}-${zoxide_arch}.tar.gz"
    fi

    if [ -z "$url" ]; then
        if $CAN_SUDO && [ -n "$apt_ver" ]; then
            log_warn "zoxide: could not determine latest version; falling back to apt $apt_ver"
            log_warn "zoxide: apt version <0.8 — 'zi' alias requires ≥0.8; run update.sh to upgrade"
            apt_install zoxide
            return
        fi
        log_warn "zoxide: could not determine latest version — skipping"
        return
    fi

    log_info "zoxide: installing $tag → ~/.local/bin/zoxide"
    if _download_tar_bin "$url" "zoxide" ~/.local/bin/zoxide; then
        log_ok "zoxide installed → ~/.local/bin ($(~/.local/bin/zoxide --version 2>/dev/null))"
        return
    fi

    # GitHub download failed (e.g. rate-limited in local Docker builds)
    if $CAN_SUDO && [ -n "$apt_ver" ]; then
        log_warn "zoxide: GitHub download failed; falling back to apt $apt_ver"
        log_warn "zoxide: apt version <0.8 — 'zi' alias requires ≥0.8; run update.sh to upgrade"
        apt_install zoxide
        return
    fi

    log_warn "zoxide: GitHub download failed and no apt package available — skipping"
}

# git-delta: apt on Ubuntu 24.04+; GitHub .deb on 20.04/22.04 with sudo,
# or musl tarball when no sudo is available.
_install_delta() {
    if has delta; then
        log_ok "git-delta already installed — skipping"
        return
    fi

    if $CAN_SUDO && apt-cache show git-delta &>/dev/null 2>&1; then
        apt_install git-delta
        return
    fi

    local tag ver
    tag=$(_gh_latest_tag_noapi "dandavison/delta") || tag=""
    ver="${tag#v}"

    if [ -z "$ver" ]; then
        log_warn "git-delta: could not determine latest release — skipping"
        return
    fi

    if $CAN_SUDO; then
        log_step "git-delta (GitHub .deb)"
        local arch; arch="$(_deb_arch)"
        local deb="git-delta_${ver}_${arch}.deb"
        local url="https://github.com/dandavison/delta/releases/download/${ver}/${deb}"
        log_info "git-delta: installing $ver → system (via .deb)"
        local tmp; tmp="$(mktemp -d)"
        # shellcheck disable=SC2064
        trap "rm -rf '$tmp'" RETURN
        if has curl; then
            curl -sfLo "$tmp/$deb" "$url" || { log_warn "git-delta: download failed — skipping"; return; }
        else
            wget -qO "$tmp/$deb" "$url"   || { log_warn "git-delta: download failed — skipping"; return; }
        fi
        $SUDO dpkg -i "$tmp/$deb"
        log_ok "git-delta ${ver} installed → $(command -v delta 2>/dev/null || echo 'system')"
    else
        log_step "git-delta (GitHub binary — no sudo)"
        local arch; arch=$(uname -m)
        local delta_arch
        case "$arch" in
            x86_64)  delta_arch="x86_64-unknown-linux-musl" ;;
            aarch64) delta_arch="aarch64-unknown-linux-gnu"  ;;
            *)
                log_warn "git-delta: unsupported arch $arch — skipping"
                return
                ;;
        esac
        local url="https://github.com/dandavison/delta/releases/download/${ver}/delta-${ver}-${delta_arch}.tar.gz"
        log_info "git-delta: installing $ver → ~/.local/bin/delta"
        if _download_tar_bin "$url" "delta" ~/.local/bin/delta; then
            log_ok "git-delta installed → ~/.local/bin/delta ($(~/.local/bin/delta --version 2>/dev/null))"
        else
            log_warn "git-delta: download failed — skipping"
        fi
    fi
}

# eza: apt on Ubuntu 24.04+; official PPA on 20.04/22.04 with sudo,
# or musl tarball when no sudo is available.
_install_eza() {
    if has eza; then
        log_ok "eza already installed — skipping"
        return
    fi

    if $CAN_SUDO && apt-cache show eza &>/dev/null 2>&1; then
        log_info "eza: installing via apt → system"
        apt_install eza
        return
    fi

    if $CAN_SUDO; then
        log_step "eza (official PPA)"
        log_info "eza: installing latest → system (via PPA)"
        apt_install gpg  # needed for dearmor; may already be present
        $SUDO mkdir -p /etc/apt/keyrings
        if has curl; then
            curl -fsSL https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | $SUDO gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        else
            wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
                | $SUDO gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
        fi
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
            | $SUDO tee /etc/apt/sources.list.d/gierens.list > /dev/null
        $SUDO chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        $SUDO apt-get update -yq
        apt_install eza
        log_ok "eza installed via PPA ($(eza --version 2>/dev/null | head -1))"
    else
        log_step "eza (GitHub binary — no sudo)"
        local arch; arch=$(uname -m)
        local eza_arch
        case "$arch" in
            x86_64)  eza_arch="x86_64-unknown-linux-musl" ;;
            aarch64) eza_arch="aarch64-unknown-linux-musl" ;;
            *)
                log_warn "eza: unsupported arch $arch — skipping"
                return
                ;;
        esac
        local tag; tag=$(_gh_latest_tag_noapi "eza-community/eza") || tag=""
        if [ -z "$tag" ]; then
            log_warn "eza: could not determine latest release — skipping"
            return
        fi
        local url="https://github.com/eza-community/eza/releases/download/${tag}/eza_${eza_arch}.tar.gz"
        log_info "eza: installing $tag → ~/.local/bin/eza"
        if _download_tar_bin "$url" "eza" ~/.local/bin/eza; then
            log_ok "eza installed → ~/.local/bin/eza ($(~/.local/bin/eza --version 2>/dev/null | head -1))"
        else
            log_warn "eza: download failed — skipping"
        fi
    fi
}

# ripgrep: GitHub tarball — binary is 'rg'
_install_ripgrep() {
    if has rg; then
        log_ok "ripgrep already installed — skipping"
        return
    fi
    log_step "ripgrep (GitHub binary)"
    local arch; arch=$(uname -m)
    local rg_arch
    case "$arch" in
        x86_64)  rg_arch="x86_64-unknown-linux-musl" ;;
        aarch64) rg_arch="aarch64-unknown-linux-gnu"  ;;
        *)
            log_warn "ripgrep: unsupported arch $arch — skipping"
            return
            ;;
    esac
    local tag; tag=$(_gh_latest_tag_noapi "BurntSushi/ripgrep") || tag=""
    if [ -z "$tag" ]; then
        log_warn "ripgrep: could not determine latest release — skipping"
        return
    fi
    local ver="${tag#v}"
    local url="https://github.com/BurntSushi/ripgrep/releases/download/${tag}/ripgrep-${ver}-${rg_arch}.tar.gz"
    log_info "ripgrep: installing $tag → ~/.local/bin/rg"
    if _download_tar_bin "$url" "rg" ~/.local/bin/rg; then
        log_ok "ripgrep installed → ~/.local/bin/rg ($(~/.local/bin/rg --version 2>/dev/null | head -1))"
    else
        log_warn "ripgrep: download failed — skipping"
    fi
}

# fd: GitHub tarball — binary is 'fd'
_install_fd() {
    if has fd || has fdfind; then
        log_ok "fd already installed — skipping"
        return
    fi
    log_step "fd (GitHub binary)"
    local arch; arch=$(uname -m)
    local fd_arch
    case "$arch" in
        x86_64)  fd_arch="x86_64-unknown-linux-musl" ;;
        aarch64) fd_arch="aarch64-unknown-linux-gnu"  ;;
        *)
            log_warn "fd: unsupported arch $arch — skipping"
            return
            ;;
    esac
    local tag; tag=$(_gh_latest_tag_noapi "sharkdp/fd") || tag=""
    if [ -z "$tag" ]; then
        log_warn "fd: could not determine latest release — skipping"
        return
    fi
    local url="https://github.com/sharkdp/fd/releases/download/${tag}/fd-${tag}-${fd_arch}.tar.gz"
    log_info "fd: installing $tag → ~/.local/bin/fd"
    if _download_tar_bin "$url" "fd" ~/.local/bin/fd; then
        log_ok "fd installed → ~/.local/bin/fd ($(~/.local/bin/fd --version 2>/dev/null))"
    else
        log_warn "fd: download failed — skipping"
    fi
}

# jq: GitHub single-binary release
_install_jq() {
    if has jq; then
        log_ok "jq already installed — skipping"
        return
    fi
    log_step "jq (GitHub binary)"
    local arch; arch=$(uname -m)
    local jq_arch
    case "$arch" in
        x86_64)  jq_arch="amd64" ;;
        aarch64) jq_arch="arm64" ;;
        *)
            log_warn "jq: unsupported arch $arch — skipping"
            return
            ;;
    esac
    local tag; tag=$(_gh_latest_tag_noapi "jqlang/jq") || tag=""
    if [ -z "$tag" ]; then
        log_warn "jq: could not determine latest release — skipping"
        return
    fi
    local url="https://github.com/jqlang/jq/releases/download/${tag}/jq-linux-${jq_arch}"
    log_info "jq: installing $tag → ~/.local/bin/jq"
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
        log_warn "jq: download failed — skipping"
        rm -f ~/.local/bin/jq
    fi
}

# fzf: install via git clone so shell integration (~/.fzf.zsh) is generated
# automatically by the installer. This matches how update.sh manages fzf and
# what .zshrc expects (`source ~/.fzf.zsh`).
# A ~/.local/bin/fzf symlink is created so fzf is on PATH without sourcing
# ~/.fzf.zsh (important for install.sh and test.sh which don't source it).
_install_fzf() {
    if [ -d ~/.fzf ]; then
        log_ok "fzf already installed — skipping"
        return
    fi
    log_step "fzf (git clone)"
    log_info "fzf: installing latest → ~/.fzf/ (shell integration via ~/.fzf.zsh, binary symlinked to ~/.local/bin/fzf)"
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf --quiet
    ~/.fzf/install --no-update-rc --key-bindings --completion
    mkdir -p ~/.local/bin
    ln -sf ~/.fzf/bin/fzf ~/.local/bin/fzf
    log_ok "fzf installed → ~/.fzf (symlinked to ~/.local/bin/fzf)"
}
