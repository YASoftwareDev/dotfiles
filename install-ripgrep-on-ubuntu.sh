#!/bin/bash
[[ $UID == 0 ]] || { echo "run as sudo to install"; exit 1; }

REPO="https://github.com/BurntSushi/ripgrep/releases/download/"
RG_LATEST=$(curl -sSL "https://api.github.com/repos/BurntSushi/ripgrep/releases/latest" | jq --raw-output .tag_name)
RELEASE="${RG_LATEST}/ripgrep-${RG_LATEST}-x86_64-unknown-linux-musl.tar.gz"

TMPDIR=$(mktemp -d)
cd $TMPDIR
wget -O - ${REPO}${RELEASE} | tar zxf - --strip-component=1
mv rg /usr/local/bin/
[ -d /usr/local/share/man/man1 ] && cp doc/rg.1 /usr/local/share/man/man1/
[ -d /usr/share/man/man1 ] && cp doc/rg.1 /usr/share/man/man1/
mv complete/rg.bash /usr/share/bash-completion/completions/rg
chmod g-w,o-w complete/_rg
chown root:root complete/_rg
mv complete/_rg  /usr/share/zsh/functions/Completion
mandb
