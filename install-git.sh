#!/bin/bash

set -euo pipefail

sudo apt-get install make autoconf libcurl4-gnutls-dev gettext gcc zlib1g-dev

wget -O - https://github.com/git/git/archive/v2.29.2.tar.gz | tar xz
cd v2.29.2

make configure
./configure --prefix=/usr --without-tcltk
make all -j
sudo make install

## For docs:
#cd ..
#git clone git://github.com/gitster/git-manpages.git
#cd -
#sudo make quick-install-man

#cd ..
#rm -rf v2.29.2

