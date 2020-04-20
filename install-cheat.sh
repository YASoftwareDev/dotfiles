#!/bin/bash

# cheat - allows you to create and view interactive cheatsheets on the command-line
# https://github.com/cheat/cheat

REPO="https://github.com/cheat/cheat/releases/download/"
CHEAT_LATEST=$(curl -sSL "https://api.github.com/repos/cheat/cheat/releases/latest" | jq --raw-output .tag_name)
RELEASE="${CHEAT_LATEST}/cheat-linux-amd64.gz"
wget ${REPO}${RELEASE} -O cheat.gz
gunzip cheat.gz
chmod u+x cheat
mkdir -p ~/.local/bin
mv cheat ~/.local/bin
