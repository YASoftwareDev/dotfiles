#!/bin/bash

set -euo pipefail

wget -O - https://github.com/Kitware/CMake/releases/download/v3.19.0/cmake-3.19.0.tar.gz | tar xz
cd cmake-3.19.0

./bootstrap --parallel=4 -- -DCMAKE_BUILD_TYPE:STRING=Release
make -j
sudo make install

#cd ..
#rm -rf cmake-3.19.0
