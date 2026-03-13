#!/usr/bin/env bash
# Update all managed tools and plugins
# Safe to run periodically — updates in-place, no reinstall needed
#
# Usage: update.sh [--check] [tool ...]
#
#   --check, -c    Show current vs latest versions without making any changes
#   --help,  -h    Show this message
#
# Available tools (pass one or more to update only those):
#   apt  omz  tmux-plugins  zsh-plugins  fzf  rg  fd  shellcheck
#   zoxide  delta  eza  uv  ruff  neovim  cheat  pre-commit
#
# Examples:
#   ./update.sh --check              # check all versions
#   ./update.sh --check neovim fzf  # check only neovim and fzf
#   ./update.sh neovim              # update only neovim
#   NOSUDO=1 ./update.sh            # skip apt upgrade, skip all sudo operations

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${DOTFILES_DIR}/lib/utils.sh"

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ARCH=$(uname -m)   # x86_64, aarch64, armv7l, …

# ── Argument parsing ───────────────────────────────────────────────────────────

CHECK_ONLY=false
SELECTED=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --check|-c) CHECK_ONLY=true ;;
        --help|-h)
            sed -n '5,17p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
            exit 0
            ;;
        -*) echo "Unknown option: $1" >&2; exit 1 ;;
        *)  SELECTED+=("$1") ;;
    esac
    shift
done

_KNOWN_TOOLS=(apt omz tmux-plugins zsh-plugins fzf rg fd shellcheck
              zoxide delta eza uv ruff neovim cheat pre-commit)

# Validate SELECTED against known tool names.
for _sel in "${SELECTED[@]+"${SELECTED[@]}"}"; do
    _found=false
    for _known in "${_KNOWN_TOOLS[@]}"; do
        [[ "$_sel" == "$_known" ]] && _found=true && break
    done
    if ! $_found; then
        echo "Unknown tool: '$_sel'" >&2
        echo "Run '${BASH_SOURCE[0]} --help' for available tools." >&2
        exit 1
    fi
done
unset _sel _found _known

# Returns 0 (run this step) or 1 (skip it).
_should_run() {
    [[ ${#SELECTED[@]} -eq 0 ]] && return 0
    local name
    for name in "${SELECTED[@]}"; do
        [[ "$name" == "$1" ]] && return 0
    done
    return 1
}

# Update a standard GitHub binary release using Rust triple naming (tar.gz).
# Usage: _update_std_tool CMD LABEL REPO GNU_ARM [BINARY] [ASSET_PREFIX]
#   GNU_ARM: "gnu" → aarch64 uses GNU triple; otherwise musl for both arches
_update_std_tool() {
    local cmd="$1" label="$2" repo="$3" gnu_arm="$4"
    local binary="${5:-$1}" prefix="${6:-}"
    _should_run "$cmd" || return 0
    log_step "$label"
    if ! has "$cmd"; then
        log_warn "$label not installed — skipping"
        return
    fi
    local arch
    case "$ARCH" in
        x86_64)  arch="x86_64-unknown-linux-musl" ;;
        aarch64) [ "$gnu_arm" = "gnu" ] && arch="aarch64-unknown-linux-gnu" || arch="aarch64-unknown-linux-musl" ;;
        *)       log_warn "$label: unsupported arch $ARCH — skipping"; return ;;
    esac
    local dest; dest=$(_resolve_dest "$binary" ~/.local/bin/"$binary")
    _gh_update_binary "$cmd" "$repo" "${prefix}${arch}.tar.gz" "$binary" "$dest" || true
}

# uv installs two binaries (uv + uvx) from one tarball — needs a custom handler.
_do_update_uv() {
    local uv_arch
    case "$ARCH" in
        x86_64)  uv_arch="x86_64-unknown-linux-musl"  ;;
        aarch64) uv_arch="aarch64-unknown-linux-musl" ;;
        *)       log_warn "uv: unsupported arch $ARCH — skipping"; return ;;
    esac
    if $CHECK_ONLY; then
        local current; current=$(_cmd_version uv --version) || current=""
        local latest; latest=$(_gh_latest_tag "astral-sh/uv") || latest=""
        _report_version uv "$current" "${latest:-unknown}"
        return
    fi
    local url; url=$(_gh_latest_release "astral-sh/uv" "uv-${uv_arch}.tar.gz") || url=""
    if [ -z "$url" ]; then log_warn "uv: could not fetch release URL — skipping"; return; fi
    local tmp; tmp=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN
    if has curl; then curl -sfL "$url" | tar -xz -C "$tmp"
    else wget -qO- "$url" | tar -xz -C "$tmp"; fi
    for bin in uv uvx; do
        local found; found=$(find "$tmp" -name "$bin" -type f | head -1)
        [ -n "$found" ] && mv "$found" ~/.local/bin/"$bin" && chmod +x ~/.local/bin/"$bin"
    done
    if has uv; then
        log_ok "uv updated → ~/.local/bin ($(uv --version 2>/dev/null))"
        _verify_dest uv ~/.local/bin/uv
        _verify_dest uvx ~/.local/bin/uvx
    else
        log_warn "uv: binary not found in archive — update may have failed"
    fi
}

# neovim uses a directory tree (not a single binary) and skips when already current.
_do_update_neovim() {
    local nvim_arch
    case "$ARCH" in
        x86_64)  nvim_arch="linux-x86_64" ;;
        aarch64) nvim_arch="linux-arm64"  ;;
        *)       log_warn "neovim: unsupported arch $ARCH — skipping"; return ;;
    esac
    local latest_tag="" nvim_url=""
    read -r latest_tag nvim_url < <(_gh_release_info "neovim/neovim" "nvim-${nvim_arch}.tar.gz") || true
    local latest="${latest_tag#v}"
    local current; current=$(_cmd_version nvim --version) || current=""
    if [ -z "$latest" ]; then
        log_warn "neovim: could not fetch release info — skipping"
        return
    fi
    if $CHECK_ONLY; then
        _report_version neovim "${current:-none}" "$latest_tag"
        if $CAN_SUDO; then
            log_info "  → update would install to /usr/local/ (sudo available)"
        else
            log_info "  → update would install to ~/.local/ (no sudo)"
        fi
        return
    fi
    if [ "$current" = "$latest" ]; then
        log_ok "neovim $latest_tag already up to date"
        return
    fi
    log_info "neovim: upgrading ${current:-none} → $latest"
    if [ -z "$nvim_url" ]; then
        log_warn "neovim: could not fetch download URL — skipping"
        return
    fi
    local tmp; tmp=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmp'" RETURN
    if has curl; then curl -sfL "$nvim_url" | tar -xz -C "$tmp"
    else wget -qO- "$nvim_url" | tar -xz -C "$tmp"; fi
    local extracted; extracted=$(find "$tmp" -maxdepth 1 -type d -name 'nvim-*' | head -1)
    if [ -z "$extracted" ]; then log_warn "neovim: unexpected archive layout — skipping"; return; fi
    local nvim_dest
    if $CAN_SUDO; then
        $SUDO cp -r "$extracted"/. /usr/local/
        nvim_dest=/usr/local/bin/nvim
    else
        cp -r "$extracted"/. "$HOME/.local/"
        nvim_dest=$HOME/.local/bin/nvim
    fi
    log_ok "neovim updated → $(nvim --version 2>/dev/null | head -1)"
    _verify_dest nvim "$nvim_dest"
}

# ── System packages ────────────────────────────────────────────────────────────
log_info "Checking sudo access…"
detect_sudo
case "$SUDO_STATUS" in
    root)              log_ok   "Running as root — apt upgrades will run directly" ;;
    sudo_passwordless) log_ok   "sudo available — apt upgrades will run via sudo" ;;
    sudo_password)
        log_ok   "sudo available — apt upgrades will run via sudo"
        log_warn "sudo requires a password — you will be prompted when apt runs" ;;
    nosudo)            log_warn "No sudo — apt upgrade skipped" ;;
esac
if _should_run apt; then
    log_step "System packages (apt)"
    if $CAN_SUDO; then
        if $CHECK_ONLY; then
            apt list --upgradable 2>/dev/null | grep -v '^Listing' || true
            log_info "  → sudo required to apply these updates"
        else
            $SUDO apt-get -yq update
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get -yq upgrade
            log_ok "System packages updated"
        fi
    else
        log_warn "No sudo — skipping apt upgrade"
    fi
fi

# ── oh-my-zsh ──────────────────────────────────────────────────────────────────
if _should_run omz; then
    log_step "oh-my-zsh"
    if [ -d ~/.oh-my-zsh ]; then
        if $CHECK_ONLY; then
            _check_git_updates "oh-my-zsh" ~/.oh-my-zsh
        else
            zsh -c 'source ~/.oh-my-zsh/oh-my-zsh.sh; omz update --unattended' 2>/dev/null \
                || git -C ~/.oh-my-zsh pull --quiet
            log_ok "oh-my-zsh updated"
        fi
    else
        log_warn "oh-my-zsh not installed — skipping"
    fi
fi

# ── tmux plugins ───────────────────────────────────────────────────────────────
if _should_run tmux-plugins; then
    log_step "tmux plugins"
    for _tmux_plugin in tmux-resurrect tmux-continuum tmux-fzf tmux-cpu; do
        if $CHECK_ONLY; then
            _check_git_updates "$_tmux_plugin" "$HOME/.tmux/plugins/$_tmux_plugin"
        else
            _update_plugin "$_tmux_plugin" "$HOME/.tmux/plugins/$_tmux_plugin"
        fi
    done
fi

# ── zsh plugins ────────────────────────────────────────────────────────────────
if _should_run zsh-plugins; then
    log_step "zsh plugins"
    if $CHECK_ONLY; then
        _check_git_updates "powerlevel10k"            "$ZSH_CUSTOM/themes/powerlevel10k"
        _check_git_updates "zsh-autosuggestions"      "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        _check_git_updates "fast-syntax-highlighting" "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
        _check_git_updates "fzf-tab"                  "$ZSH_CUSTOM/plugins/fzf-tab"
    else
        _update_plugin "powerlevel10k"            "$ZSH_CUSTOM/themes/powerlevel10k"
        _update_plugin "zsh-autosuggestions"      "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
        _update_plugin "fast-syntax-highlighting" "$ZSH_CUSTOM/plugins/fast-syntax-highlighting"
        _update_plugin "fzf-tab"                  "$ZSH_CUSTOM/plugins/fzf-tab"
    fi
fi

# ── fzf ────────────────────────────────────────────────────────────────────────
# Installed via git clone (~/.fzf) — update by pulling the repo.
# Shell integration lives in ~/.fzf.zsh (generated by ~/.fzf/install at
# install time) and is sourced by .zshrc.
if _should_run fzf; then
    log_step "fzf"
    if [ -d ~/.fzf/.git ]; then
        if $CHECK_ONLY; then
            _check_git_updates "fzf" ~/.fzf
        else
            if git -C ~/.fzf pull --quiet --rebase; then
                ver=$(_cmd_version ~/.fzf/bin/fzf --version) || ver="?"
                log_ok "fzf updated → ~/.fzf ($ver)"
            else
                log_warn "fzf: git pull failed — skipping"
            fi
        fi
    elif has fzf; then
        log_warn "fzf: not managed as a git clone at ~/.fzf — skipping (update manually)"
    else
        log_warn "fzf not installed — skipping"
    fi
fi

# ── ripgrep ────────────────────────────────────────────────────────────────────
_update_std_tool rg "ripgrep" "BurntSushi/ripgrep" gnu

# ── fd ─────────────────────────────────────────────────────────────────────────
# Special case: fd may be installed as fdfind (Debian/Ubuntu); always put the
# updated binary at ~/.local/bin/fd regardless of where the current one lives.
if _should_run fd; then
    log_step "fd"
    if has fd || has fdfind; then
        case "$ARCH" in
            x86_64)  _gh_update_binary fd "sharkdp/fd" "x86_64-unknown-linux-musl.tar.gz" fd ~/.local/bin/fd || true ;;
            aarch64) _gh_update_binary fd "sharkdp/fd" "aarch64-unknown-linux-gnu.tar.gz"  fd ~/.local/bin/fd || true ;;
            *)       log_warn "fd: unsupported arch $ARCH — skipping" ;;
        esac
    else
        log_warn "fd not installed — skipping"
    fi
fi

# ── shellcheck ─────────────────────────────────────────────────────────────────
# Uses bare arch names (x86_64/aarch64), not Rust triples — keep its own section.
if _should_run shellcheck; then
    log_step "shellcheck"
    if has shellcheck; then
        sc_arch=""
        case "$ARCH" in
            x86_64)  sc_arch="x86_64"  ;;
            aarch64) sc_arch="aarch64" ;;
            *)       log_warn "shellcheck: unsupported arch $ARCH — skipping" ;;
        esac
        if [ -n "$sc_arch" ]; then
            dest=$(_resolve_dest shellcheck ~/.local/bin/shellcheck)
            _gh_update_binary shellcheck "koalaman/shellcheck" \
                "linux.${sc_arch}.tar.xz" shellcheck "$dest" || true
        fi
    else
        log_warn "shellcheck not installed — skipping"
    fi
fi

# ── zoxide ──────────────────────────────────────────────────────────────────────────────
_update_std_tool zoxide "zoxide" "ajeetdsouza/zoxide" musl

# ── delta ───────────────────────────────────────────────────────────────────────────────
_update_std_tool delta "delta" "dandavison/delta" gnu

# ── eza ────────────────────────────────────────────────────────────────────────────────
# Asset pattern has an eza_ prefix before the arch triple.
_update_std_tool eza "eza" "eza-community/eza" musl eza "eza_"

# ── uv ───────────────────────────────────────────────────────────────────────────
# Custom: installs two binaries (uv + uvx) from a single tarball.
if _should_run uv; then
    log_step "uv"
    if has uv; then
        _do_update_uv
    else
        log_warn "uv not installed — skipping (run install.sh workstation first)"
    fi
fi

# ── ruff ───────────────────────────────────────────────────────────────────────
if _should_run ruff; then
    log_step "ruff"
    if has uv && uv tool list 2>/dev/null | grep -q '^ruff '; then
        if $CHECK_ONLY; then
            log_info "ruff: installed=$(ruff --version 2>/dev/null)  (latest: pypi.org/project/ruff)"
        else
            uv tool upgrade ruff --quiet
            log_ok "ruff updated ($(ruff --version 2>/dev/null))"
        fi
    elif has ruff; then
        log_warn "ruff: not managed by uv tool — skipping (update manually)"
    else
        log_warn "ruff not installed — skipping"
    fi
fi

# ── neovim ────────────────────────────────────────────────────────────────────────────
# Custom: extracts a directory tree, single API call, skips when already current.
if _should_run neovim; then
    log_step "neovim"
    _do_update_neovim
fi

# ── cheat ──────────────────────────────────────────────────────────────────────
# Custom: single compressed binary (gunzip, not tarball).
if _should_run cheat; then
    log_step "cheat"
    if [ -f ~/.local/bin/cheat ]; then
        if $CHECK_ONLY; then
            current=$(_cmd_version ~/.local/bin/cheat --version) || current=""
            latest=$(_gh_latest_tag "cheat/cheat") || latest=""
            _report_version cheat "$current" "${latest:-unknown}"
        else
            case "$ARCH" in
                x86_64)  cheat_arch="amd64" ;;
                aarch64) cheat_arch="arm64" ;;
                *)       cheat_arch=""      ;;
            esac
            if [ -z "$cheat_arch" ]; then
                log_warn "cheat: unsupported arch $ARCH — skipping"
            else
                url=$(_gh_latest_release "cheat/cheat" "linux-${cheat_arch}\"") || url=""
                if [ -n "$url" ]; then
                    if has curl; then curl -sfL "$url" | gunzip > ~/.local/bin/cheat
                    else wget -qO- "$url" | gunzip > ~/.local/bin/cheat; fi
                    chmod +x ~/.local/bin/cheat
                    log_ok "cheat updated"
                    _verify_dest cheat ~/.local/bin/cheat
                else
                    log_warn "cheat: could not fetch release URL — skipping"
                fi
            fi
        fi
    else
        log_warn "cheat not installed — run install.sh workstation first"
    fi
fi

# ── pre-commit common repo ─────────────────────────────────────────────────────
if _should_run pre-commit; then
    log_step "pre-commit (common repo)"
    PRECOMMIT_REPO="${PRECOMMIT_REPO:-$HOME/projects/common/pre-commit}"
    if [ -d "$PRECOMMIT_REPO/.git" ]; then
        if $CHECK_ONLY; then
            _check_git_updates "pre-commit" "$PRECOMMIT_REPO"
        else
            if git -C "$PRECOMMIT_REPO" pull --quiet --rebase; then
                log_ok "pre-commit repo updated ($PRECOMMIT_REPO)"
                log_info "  Note: re-run pre-commit/install.sh in each project to upgrade the tool version"
            else
                log_warn "pre-commit repo pull failed — skipping (local changes or network issue?)"
            fi
        fi
    else
        log_warn "pre-commit repo not found at $PRECOMMIT_REPO — skipping"
        log_warn "  To override: PRECOMMIT_REPO=/your/path ./update.sh"
    fi
fi

echo ""
if $CHECK_ONLY; then
    log_ok "Check complete"
else
    log_ok "Update complete — restart your shell to apply changes"
fi
echo ""
