#!/usr/bin/env bash
# Install and test the dotfiles under a git with no partial-clone support.
#
# Runs INSIDE an old-userland container (Ubuntu 16.04, git 2.7.4) with the repo
# mounted read-only at /dotfiles. The job cannot use `container: ubuntu:16.04`
# directly: actions/checkout runs on Node 20/24, which needs glibc >= 2.28 while
# 16.04 ships 2.23, so the checkout step fails before anything is tested.
#
# What this covers that no other cell does: init.lua falls back to full clones
# where `git clone --filter=blob:none` is unavailable, and git 2.7.4 is also below
# the 2.13 needed to check out the lockfile pins.
#
# Run it locally exactly as CI does:
#   docker run --rm -e GH_TOKEN -v "$PWD":/dotfiles:ro ubuntu:16.04 \
#       bash /dotfiles/tests/ci-old-git.sh
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get -yq update
# Keep resolvconf's post-install from failing on a Docker-bound /etc/resolv.conf.
echo "resolvconf resolvconf/linkify-resolvconf boolean false" | debconf-set-selections
apt-get -yq install apt-utils git sudo curl ca-certificates

echo "git $(git --version)"

# Assert the DISCRIMINATING CONDITION, not a version number. Measured 2026-09-17:
# git 2.17.1 (Ubuntu 18.04) accepts --filter, so a `< 2.19` check passes while the
# fallback never runs - a cell that is green and proves nothing.
if git clone --filter=blob:none --depth=1 \
        https://github.com/folke/lazy.nvim /tmp/filter-probe >/tmp/filter-probe.log 2>&1; then
    echo "FATAL: this git ACCEPTS --filter, so the full-clone fallback is not exercised here"
    exit 1
fi
echo "rejects --filter as required: $(head -1 /tmp/filter-probe.log)"

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

su -s /bin/bash -c 'HOME=/home/testuser; export HOME; cd ~/dotfiles && bash install.sh minimal' testuser

# 16.04's apt has no neovim at all, and test.sh's config check covers 0.9-0.11 only,
# so without seeding it would skip and the plugin bootstrap would never run here.
cd /home/testuser/dotfiles
DOTFILES_DIR=$PWD bash -c 'set -euo pipefail
source lib/utils.sh; detect_sudo; source modules/neovim.sh; _neovim_legacy_binary /usr/local'
nv=$(/usr/local/bin/nvim --version | head -1)
echo "$nv"
[ "$nv" = "NVIM v0.9.5" ]

su -s /bin/bash -c 'HOME=/home/testuser; export HOME; export TERM=xterm-256color; cd ~/dotfiles && bash test.sh minimal' testuser
