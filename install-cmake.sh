#!/bin/bash

set -euo pipefail

if ! [ $(id -u) = 0 ]; then
    echo "sudo required! - run with sudoer privileges: 'sudo $0'"
    exit 1
fi

wget -O - https://github.com/Kitware/CMake/releases/download/v3.19.0/cmake-3.19.0.tar.gz | tar xz
cd cmake-3.*

./bootstrap
make -j
sudo make install
