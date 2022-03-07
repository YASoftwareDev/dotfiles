#!/bin/bash

TIG_LATEST_URL=$(curl -sL https://api.github.com/repos/jonas/tig/releases/latest | jq -r '.assets[0].browser_download_url' )
wget "${TIG_LATEST_URL}" -O - | tar xz

TIG_DIR="$(basename ${TIG_LATEST_URL%.tar.gz})"
pushd "${TIG_DIR}"

make -j
make install

popd

rm -rf "${TIG_DIR}"
