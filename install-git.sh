#!/bin/bash

set -euo pipefail

if ! [ $(id -u) = 0 ]; then
    echo "sudo required! - run with sudoer privileges: 'sudo $0'"
    exit 1
fi

wget -O - https://github.com/git/git/archive/v2.29.2.tar.gz | tar xz
cd git-*

sudo apt-get install make autoconf libcurl4-gnutls-dev gettext gcc zlib1g-dev

make configure
./configure --prefix=/usr --without-tcltk
make all -j
sudo make install

## For docs:
#cd ..
#git clone git://github.com/gitster/git-manpages.git
#cd -
#sudo make quick-install-man

