#!/usr/bin/env bash
# Base system packages — requires apt (Ubuntu/Debian)
# Idempotent: apt handles "already installed" gracefully

install_base() {
    log_step "Base packages"
    if ! $CAN_SUDO; then
        log_warn "Skipping system packages (no sudo)"
        return
    fi

    $SUDO apt-get -yq update
    apt_install \
        git curl wget \
        zsh tmux neovim \
        ranger jq \
        man-db gnupg \
        python3 python3-venv \
        ripgrep fd-find tig \
        parallel shellcheck

    # fd is installed as 'fdfind' on Debian/Ubuntu — add a shim if fd is missing
    if ! has fd && has fdfind; then
        mkdir -p ~/.local/bin
        ln -sf "$(command -v fdfind)" ~/.local/bin/fd
        log_ok "Created fd → fdfind shim in ~/.local/bin"
    fi

    _install_fzf
    _install_zoxide
    _install_delta
    _install_eza

    log_ok "Base packages installed"
}

install_base_docker() {
    log_step "Base packages (docker mode)"
    if ! $CAN_SUDO; then
        log_warn "Skipping system packages (no sudo)"
        return
    fi

    $SUDO apt-get -yq update
    apt_install locales
    $SUDO locale-gen en_US.UTF-8
    $SUDO update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8

    apt_install \
        git curl wget \
        zsh tmux neovim \
        jq \
        ripgrep fd-find \
        shellcheck

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

    if [ "$major" -gt 0 ] || [ "$minor" -ge 8 ]; then
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
        if [ -n "$apt_ver" ]; then
            log_warn "zoxide: could not determine latest version; falling back to apt $apt_ver"
            log_warn "zoxide: apt version <0.8 — 'zi' alias requires ≥0.8; run update.sh to upgrade"
            apt_install zoxide
            return
        fi
        log_warn "zoxide: could not determine latest version — skipping"
        return
    fi

    if _download_tar_bin "$url" "zoxide" ~/.local/bin/zoxide; then
        log_ok "zoxide installed → ~/.local/bin ($(~/.local/bin/zoxide --version 2>/dev/null))"
        return
    fi

    # GitHub download failed (e.g. rate-limited in local Docker builds)
    if [ -n "$apt_ver" ]; then
        log_warn "zoxide: GitHub download failed; falling back to apt $apt_ver"
        log_warn "zoxide: apt version <0.8 — 'zi' alias requires ≥0.8; run update.sh to upgrade"
        apt_install zoxide
        return
    fi

    log_warn "zoxide: GitHub download failed and no apt package available — skipping"
}

# git-delta: apt on Ubuntu 24.04+; GitHub .deb binary on 20.04/22.04
_install_delta() {
    if has delta; then
        log_ok "git-delta already installed — skipping"
        return
    fi

    if apt-cache show git-delta &>/dev/null 2>&1; then
        apt_install git-delta
        return
    fi

    log_step "git-delta (GitHub binary)"
    local arch; arch="$(_deb_arch)"
    local tag ver
    tag=$(_gh_latest_tag_noapi "dandavison/delta") || tag=""
    ver="${tag#v}"

    if [ -z "$ver" ]; then
        log_warn "git-delta: could not determine latest release — skipping"
        return
    fi

    local deb="git-delta_${ver}_${arch}.deb"
    local url="https://github.com/dandavison/delta/releases/download/${ver}/${deb}"
    local tmp; tmp="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN

    if has curl; then
        curl -sfLo "$tmp/$deb" "$url" || { log_warn "git-delta: download failed — skipping"; return; }
    else
        wget -qO "$tmp/$deb" "$url"   || { log_warn "git-delta: download failed — skipping"; return; }
    fi

    $SUDO dpkg -i "$tmp/$deb"
    log_ok "git-delta ${ver} installed"
}

# eza: apt on Ubuntu 24.04+; official PPA (deb.gierens.de) on 20.04/22.04
_install_eza() {
    if has eza; then
        log_ok "eza already installed — skipping"
        return
    fi

    if apt-cache show eza &>/dev/null 2>&1; then
        apt_install eza
        return
    fi

    log_step "eza (official PPA)"
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
    log_ok "eza installed via PPA"
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
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf --quiet
    ~/.fzf/install --no-update-rc --key-bindings --completion
    mkdir -p ~/.local/bin
    ln -sf ~/.fzf/bin/fzf ~/.local/bin/fzf
    log_ok "fzf installed → ~/.fzf (symlinked to ~/.local/bin/fzf)"
}
