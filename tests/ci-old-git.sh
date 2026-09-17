#!/usr/bin/env bash
# Install, update and test the dotfiles under a git with no partial-clone support.
#
# Runs INSIDE an old-userland container (Ubuntu 16.04: git 2.7.4, bash 4.3,
# glibc 2.23) with the repo mounted read-only at /dotfiles. The job cannot use
# `container: ubuntu:16.04` directly: actions/checkout runs on Node 20/24, which
# needs glibc >= 2.28, so the checkout step fails before anything is tested.
#
# What this covers that no other cell does:
#   - init.lua's full-clone fallback, where `git clone --filter=blob:none` is
#     unavailable; git 2.7.4 is also below the 2.13 needed to check out the pins
#   - install.sh, its idempotency re-run, update.sh and the re-test on bash 4.3
#   - update.sh upgrading nvim on glibc 2.23, i.e. the neovim-releases
#     glibc-2.17 fallback on genuinely old glibc
#
# Run it locally exactly as CI does:
#   docker run --rm -e GH_TOKEN -v "$PWD":/dotfiles:ro ubuntu:16.04 \
#       bash /dotfiles/tests/ci-old-git.sh
set -euo pipefail

_step() { printf '\n===== %s =====\n' "$1"; }
_as_user() { su -s /bin/bash -c "HOME=/home/testuser; export HOME; export TERM=xterm-256color; cd ~/dotfiles && $1" testuser; }

_step "Bootstrap"
export DEBIAN_FRONTEND=noninteractive
apt-get -yq update
# Keep resolvconf's post-install from failing on a Docker-bound /etc/resolv.conf.
echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections
apt-get -yq install apt-utils git sudo curl ca-certificates
echo "git $(git --version)"
echo "bash ${BASH_VERSION}"
echo "glibc $(ldd --version | head -1)"

_step "Assert this git rejects --filter"
# Assert the DISCRIMINATING CONDITION, not a version number. Measured 2026-09-17:
# git 2.17.1 (Ubuntu 18.04) accepts --filter, so a `< 2.19` check passes while the
# fallback never runs - a cell that is green and proves nothing.
if git clone --filter=blob:none --depth=1 \
        https://github.com/folke/lazy.nvim /tmp/filter-probe >/tmp/filter-probe.log 2>&1; then
    echo "FATAL: this git ACCEPTS --filter, so the full-clone fallback is not exercised here"
    exit 1
fi
echo "rejects --filter as required: $(head -1 /tmp/filter-probe.log)"

_step "Prepare the test user"
useradd -m -s /bin/bash testuser
echo 'testuser ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
cp -r /dotfiles /home/testuser/dotfiles
chown -R testuser:testuser /home/testuser/dotfiles
# Same GitHub API rate-limit workaround the other cells use.
if [ -n "${GH_TOKEN:-}" ]; then
    printf 'header = "Authorization: Bearer %s"\n' "$GH_TOKEN" > /home/testuser/.curlrc
    chown testuser:testuser /home/testuser/.curlrc
    chmod 600 /home/testuser/.curlrc
fi

_step "Install (minimal)"
_as_user 'bash install.sh minimal'

_step "Idempotency - re-run install.sh"
_as_user 'bash install.sh minimal'

_step "Seed nvim v0.9.5"
# 16.04's apt has no neovim at all, and test.sh's config check covers 0.9-0.11
# only, so without seeding it would skip and the plugin bootstrap - the whole
# point of this cell - would never run.
cd /home/testuser/dotfiles
DOTFILES_DIR=$PWD bash -c 'set -euo pipefail
source lib/utils.sh; detect_sudo; source modules/neovim.sh; _neovim_legacy_binary /usr/local'
nv=$(/usr/local/bin/nvim --version | head -1)
echo "$nv"
[ "$nv" = "NVIM v0.9.5" ]

_step "Run test suite (minimal)"
_as_user 'bash test.sh minimal'

_step "Run update.sh"
_as_user 'bash update.sh'

_step "nvim still works after update"
# update.sh upgrades nvim; on glibc 2.23 that must take the neovim-releases
# glibc-2.17 path rather than an official build that cannot start here.
nv_after=$(nvim --version 2>/dev/null | head -1 || echo "FAILED TO RUN")
echo "nvim after update: $nv_after"
case "$nv_after" in NVIM\ v*) ;; *) echo "FATAL: nvim does not run after update.sh"; exit 1 ;; esac

_step "Re-run test suite after update"
_as_user 'bash test.sh minimal'
