#!/usr/bin/env bash
# Update all managed tools and plugins
# Safe to run periodically — updates in-place, no reinstall needed

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DOTFILES_DIR}/lib/utils.sh"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ARCH=$(uname -m)   # x86_64, aarch64, armv7l, …

# ── Helpers ───────────────────────────────────────────────────────────────────

# Fetch latest release download URL from GitHub for a given asset pattern.
# Usage: _gh_latest_release OWNER/REPO PATTERN
# Prints the URL, or nothing if the request fails / no match.
_gh_latest_release() {
    local repo="$1" pattern="$2"
    local api="https://api.github.com/repos/${repo}/releases/latest"
    local raw
    if has curl; then
        raw=$(curl -sfL "$api") || return 1
    else
        raw=$(wget -qO- "$api") || return 1
    fi
    printf '%s\n' "$raw" \
        | grep -o '"browser_download_url": *"[^"]*'"${pattern}"'[^"]*"' \
        | grep -o 'https://[^"]*' \
        | head -1
}

# Download a .tar.gz from URL and extract a single binary by name.
# Usage: _download_tar_bin URL BINARY_NAME DEST
_download_tar_bin() {
    local url="$1" binname="$2" dest="$3"
    mkdir -p "$(dirname "$dest")"
    local tmp
    tmp=$(mktemp -d)
    if has curl; then
        curl -sfL "$url" | tar -xz -C "$tmp"
    else
        wget -qO- "$url" | tar -xz -C "$tmp"
    fi
    local found
    found=$(find "$tmp" -name "$binname" -type f | head -1)
    if [ -z "$found" ]; then
        rm -rf "$tmp"
        return 1
    fi
    mv "$found" "$dest"
    chmod +x "$dest"
    rm -rf "$tmp"
}

# ── System packages ───────────────────────────────────────────────────────────
detect_sudo
if $CAN_SUDO; then
    log_step "System packages (apt)"
    $SUDO apt-get -yq update
    $SUDO env DEBIAN_FRONTEND=noninteractive apt-get -yq upgrade
    log_ok "System packages updated"
else
    log_warn "No sudo — skipping apt upgrade"
fi

# ── oh-my-zsh ─────────────────────────────────────────────────────────────────
log_step "oh-my-zsh"
if [ -d ~/.oh-my-zsh ]; then
    zsh -c 'source ~/.oh-my-zsh/oh-my-zsh.sh; omz update --unattended' 2>/dev/null \
        || git -C ~/.oh-my-zsh pull --quiet
    log_ok "oh-my-zsh updated"
else
    log_warn "oh-my-zsh not installed — skipping"
fi

# ── zsh plugins ───────────────────────────────────────────────────────────────
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

log_step "zsh plugins"
_update_plugin "powerlevel10k"            "$ZSH_CUSTOM/themes/powerlevel10k"
_update_plugin "zsh-autosuggestions"      "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
_update_plugin "fast-syntax-highlighting" "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
_update_plugin "fzf-tab"                  "$ZSH_CUSTOM/plugins/fzf-tab"

# ── fzf binary (GitHub releases — apt lags significantly) ─────────────────────
log_step "fzf"
if has fzf; then
    case "$ARCH" in
        x86_64)  fzf_arch="linux_amd64"   ;;
        aarch64) fzf_arch="linux_arm64"   ;;
        armv7l)  fzf_arch="linux_armv7"   ;;
        *)       fzf_arch=""              ;;
    esac
    if [ -n "$fzf_arch" ]; then
        url=$(_gh_latest_release "junegunn/fzf" "${fzf_arch}.tar.gz") || url=""
        if [ -n "$url" ]; then
            # Install alongside existing binary; prefer ~/.local/bin over system path
            dest=$(command -v fzf 2>/dev/null || echo ~/.local/bin/fzf)
            [[ "$dest" == /usr/* ]] && dest=~/.local/bin/fzf
            _download_tar_bin "$url" fzf "$dest"
            log_ok "fzf updated → $dest ($(fzf --version 2>/dev/null | head -1))"
        else
            log_warn "fzf: could not fetch release URL — skipping"
        fi
    else
        log_warn "fzf: unsupported arch $ARCH — skipping GitHub update"
    fi
else
    log_warn "fzf not installed — skipping"
fi

# ── fzf shell integration (re-download matching new binary version) ────────────
log_step "fzf shell integration"
if has fzf; then
    dest_si="/usr/share/doc/fzf/examples"
    ver=$(fzf --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?')
    case "$ver" in
        [0-9]*.[0-9]*.[0-9]*) : ;;
        [0-9]*.[0-9]*)        ver="${ver}.0" ;;
        *)                    ver="" ;;
    esac
    tag="${ver:+v$ver}"
    base="https://raw.githubusercontent.com/junegunn/fzf/${tag:-master}/shell"

    ok=true
    if has curl; then
        $SUDO curl -sfLo "$dest_si/key-bindings.zsh" "$base/key-bindings.zsh" || ok=false
        $SUDO curl -sfLo "$dest_si/completion.zsh"   "$base/completion.zsh"   || ok=false
    else
        $SUDO wget -qO "$dest_si/key-bindings.zsh" "$base/key-bindings.zsh" || ok=false
        $SUDO wget -qO "$dest_si/completion.zsh"   "$base/completion.zsh"   || ok=false
    fi
    if $ok; then
        log_ok "fzf shell integration updated (${tag:-master})"
    else
        log_warn "fzf shell integration download failed"
    fi
fi

# ── ripgrep (GitHub releases — apt lags) ──────────────────────────────────────
log_step "ripgrep"
if has rg; then
    case "$ARCH" in
        x86_64)  rg_arch="x86_64-unknown-linux-musl"  ;;
        aarch64) rg_arch="aarch64-unknown-linux-gnu"  ;;
        *)       rg_arch="" ;;
    esac
    if [ -n "$rg_arch" ]; then
        url=$(_gh_latest_release "BurntSushi/ripgrep" "${rg_arch}.tar.gz") || url=""
        if [ -n "$url" ]; then
            dest=$(command -v rg 2>/dev/null || echo ~/.local/bin/rg)
            [[ "$dest" == /usr/* ]] && dest=~/.local/bin/rg
            _download_tar_bin "$url" rg "$dest"
            log_ok "ripgrep updated → $dest ($(rg --version | head -1))"
        else
            log_warn "ripgrep: could not fetch release URL — skipping"
        fi
    else
        log_warn "ripgrep: unsupported arch $ARCH — skipping GitHub update"
    fi
else
    log_warn "ripgrep not installed — skipping"
fi

# ── fd (GitHub releases — apt ships as fdfind, may lag) ───────────────────────
log_step "fd"
if has fd || has fdfind; then
    case "$ARCH" in
        x86_64)  fd_arch="x86_64-unknown-linux-musl"  ;;
        aarch64) fd_arch="aarch64-unknown-linux-gnu"  ;;
        *)       fd_arch="" ;;
    esac
    if [ -n "$fd_arch" ]; then
        url=$(_gh_latest_release "sharkdp/fd" "${fd_arch}.tar.gz") || url=""
        if [ -n "$url" ]; then
            dest=~/.local/bin/fd
            _download_tar_bin "$url" fd "$dest"
            log_ok "fd updated → $dest ($("$dest" --version 2>/dev/null | head -1))"
        else
            log_warn "fd: could not fetch release URL — skipping"
        fi
    else
        log_warn "fd: unsupported arch $ARCH — skipping GitHub update"
    fi
else
    log_warn "fd not installed — skipping"
fi

# ── shellcheck (GitHub releases — apt lags) ───────────────────────────────────
log_step "shellcheck"
if has shellcheck; then
    case "$ARCH" in
        x86_64)  sc_arch="x86_64"  ;;
        aarch64) sc_arch="aarch64" ;;
        *)       sc_arch="" ;;
    esac
    if [ -n "$sc_arch" ]; then
        url=$(_gh_latest_release "koalaman/shellcheck" "linux.${sc_arch}.tar.xz") || url=""
        if [ -n "$url" ]; then
            dest=$(command -v shellcheck 2>/dev/null || echo ~/.local/bin/shellcheck)
            [[ "$dest" == /usr/* ]] && dest=~/.local/bin/shellcheck
            tmp=$(mktemp -d)
            if has curl; then
                curl -sfL "$url" | tar -xJ -C "$tmp"
            else
                wget -qO- "$url" | tar -xJ -C "$tmp"
            fi
            found=$(find "$tmp" -name shellcheck -type f | head -1)
            if [ -n "$found" ]; then
                mv "$found" "$dest"
                chmod +x "$dest"
                log_ok "shellcheck updated → $dest ($(shellcheck --version | grep version:))"
            else
                log_warn "shellcheck binary not found in archive"
            fi
            rm -rf "$tmp"
        else
            log_warn "shellcheck: could not fetch release URL — skipping"
        fi
    else
        log_warn "shellcheck: unsupported arch $ARCH — skipping GitHub update"
    fi
else
    log_warn "shellcheck not installed — skipping"
fi

# ── zoxide (GitHub releases — apt lags) ───────────────────────────────────────
log_step "zoxide"
if has zoxide; then
    case "$ARCH" in
        x86_64)  zo_arch="x86_64-unknown-linux-musl"  ;;
        aarch64) zo_arch="aarch64-unknown-linux-musl"  ;;
        *)       zo_arch="" ;;
    esac
    if [ -n "$zo_arch" ]; then
        url=$(_gh_latest_release "ajeetdsouza/zoxide" "${zo_arch}.tar.gz") || url=""
        if [ -n "$url" ]; then
            dest=$(command -v zoxide 2>/dev/null || echo ~/.local/bin/zoxide)
            [[ "$dest" == /usr/* ]] && dest=~/.local/bin/zoxide
            _download_tar_bin "$url" zoxide "$dest"
            log_ok "zoxide updated → $dest ($(zoxide --version 2>/dev/null))"
        else
            log_warn "zoxide: could not fetch release URL — skipping"
        fi
    else
        log_warn "zoxide: unsupported arch $ARCH — skipping GitHub update"
    fi
else
    log_warn "zoxide not installed — skipping"
fi

# ── uv (GitHub releases) ──────────────────────────────────────────────────────
log_step "uv"
if has uv; then
    case "$ARCH" in
        x86_64)  uv_arch="x86_64-unknown-linux-musl"  ;;
        aarch64) uv_arch="aarch64-unknown-linux-musl" ;;
        *)       uv_arch="" ;;
    esac
    if [ -n "$uv_arch" ]; then
        url=$(_gh_latest_release "astral-sh/uv" "uv-${uv_arch}.tar.gz") || url=""
        if [ -n "$url" ]; then
            tmp=$(mktemp -d)
            if has curl; then curl -sfL "$url" | tar -xz -C "$tmp"
            else wget -qO- "$url" | tar -xz -C "$tmp"; fi
            for bin in uv uvx; do
                found=$(find "$tmp" -name "$bin" -type f | head -1)
                [ -n "$found" ] && mv "$found" ~/.local/bin/"$bin" && chmod +x ~/.local/bin/"$bin"
            done
            rm -rf "$tmp"
            if has uv; then
                log_ok "uv updated → ~/.local/bin ($(uv --version 2>/dev/null))"
            else
                log_warn "uv: binary not found in archive — update may have failed"
            fi
        else
            log_warn "uv: could not fetch release URL — skipping"
        fi
    else
        log_warn "uv: unsupported arch $ARCH — skipping"
    fi
else
    log_warn "uv not installed — skipping (run install.sh workstation first)"
fi

# ── neovim (GitHub releases) ──────────────────────────────────────────────────
log_step "neovim"
case "$ARCH" in
    x86_64)  nvim_arch="linux-x86_64" ;;
    aarch64) nvim_arch="linux-arm64"  ;;
    *)       nvim_arch="" ;;
esac
if [ -n "$nvim_arch" ]; then
    raw=$( (has curl && curl -sfL "https://api.github.com/repos/neovim/neovim/releases/latest") \
           || (has wget && wget -qO- "https://api.github.com/repos/neovim/neovim/releases/latest") \
           || true)
    nvim_url=$(printf '%s\n' "$raw" \
        | grep -o '"browser_download_url": *"[^"]*nvim-'"${nvim_arch}"'\.tar\.gz"' \
        | grep -o 'https://[^"]*' | head -1)
    latest_tag=$(printf '%s\n' "$raw" \
        | grep -o '"tag_name": *"[^"]*"' | grep -o 'v[0-9][^"]*' | head -1)
    latest="${latest_tag#v}"
    if [ -n "$nvim_url" ] && [ -n "$latest" ]; then
        current=$(nvim --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        if [ "$current" = "$latest" ]; then
            log_ok "neovim $latest_tag already up to date"
        else
            log_info "neovim: upgrading ${current:-none} → $latest"
            tmp=$(mktemp -d)
            if has curl; then curl -sfL "$nvim_url" | tar -xz -C "$tmp"
            else wget -qO- "$nvim_url" | tar -xz -C "$tmp"; fi
            extracted=$(find "$tmp" -maxdepth 1 -type d -name 'nvim-*' | head -1)
            if [ -n "$extracted" ]; then
                if $CAN_SUDO; then $SUDO cp -r "$extracted"/. /usr/local/
                else cp -r "$extracted"/. "$HOME/.local/"; fi
                log_ok "neovim updated → $(nvim --version 2>/dev/null | head -1)"
            else
                log_warn "neovim: unexpected archive layout — skipping"
            fi
            rm -rf "$tmp"
        fi
    else
        log_warn "neovim: could not fetch release info — skipping"
    fi
else
    log_warn "neovim: unsupported arch $ARCH — skipping GitHub update"
fi

# ── diff-so-fancy ─────────────────────────────────────────────────────────────
log_step "diff-so-fancy"
if [ -f ~/.local/bin/diff-so-fancy ]; then
    if has curl; then
        curl -sfLo ~/.local/bin/diff-so-fancy \
            https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy
    else
        wget -qO ~/.local/bin/diff-so-fancy \
            https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy
    fi
    chmod +x ~/.local/bin/diff-so-fancy
    log_ok "diff-so-fancy updated"
else
    log_warn "diff-so-fancy not installed — run install.sh workstation first"
fi

# ── cheat ─────────────────────────────────────────────────────────────────────
log_step "cheat"
if [ -f ~/.local/bin/cheat ]; then
    url=$(_gh_latest_release "cheat/cheat" "linux-amd64\"") || url=""
    if [ -n "$url" ]; then
        if has curl; then
            curl -sfL "$url" | gunzip > ~/.local/bin/cheat
        else
            wget -qO- "$url" | gunzip > ~/.local/bin/cheat
        fi
        chmod +x ~/.local/bin/cheat
        log_ok "cheat updated"
    else
        log_warn "Could not fetch cheat release URL — skipping"
    fi
else
    log_warn "cheat not installed — run install.sh workstation first"
fi

# ── pre-commit common repo ────────────────────────────────────────────────────
log_step "pre-commit (common repo)"
PRECOMMIT_REPO="${PRECOMMIT_REPO:-$HOME/projects/common/pre-commit}"
if [ -d "$PRECOMMIT_REPO/.git" ]; then
    if git -C "$PRECOMMIT_REPO" pull --quiet --rebase; then
        log_ok "pre-commit repo updated ($PRECOMMIT_REPO)"
        log_info "  Note: re-run pre-commit/install.sh in each project to upgrade the tool version"
    else
        log_warn "pre-commit repo pull failed — skipping (local changes or network issue?)"
    fi
else
    log_warn "pre-commit repo not found at $PRECOMMIT_REPO — skipping"
    log_warn "  To override: PRECOMMIT_REPO=/your/path ./update.sh"
fi

echo ""
log_ok "Update complete — restart your shell to apply changes"
echo ""
