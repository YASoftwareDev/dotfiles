#!/bin/bash

# shellcheck - ShellCheck, a static analysis tool for shell scripts
# https://github.com/koalaman/shellcheck

set -euo pipefail

#scversion="stable" # or "v0.4.7", or "latest"
scversion="latest" # or "v0.4.7", or "stable"

wget -qO- "https://github.com/koalaman/shellcheck/releases/download/${scversion?}/shellcheck-${scversion?}.linux.x86_64.tar.xz" | tar -xJv
mv shellcheck-${scversion}/* ~/.local/bin
shellcheck --version
