#! /bin/bash

# Description:
#   Compile a full-featured Vim from source on Ubuntu/Debian distros. Based
#   entirely on
#   https://github.com/ycm-core/YouCompleteMe/wiki/Building-Vim-from-source
#
# Use:
#   ./compile_full_vim.sh

set -euo pipefail

sudo apt install -y libncurses5-dev libgnome2-dev libgnomeui-dev \
libgtk2.0-dev libatk1.0-dev libbonoboui2-dev \
libcairo2-dev libx11-dev libxpm-dev libxt-dev python3-distutils \
python3-dev ruby-dev lua5.1 liblua5.1-dev libperl-dev git

cd ~
git clone https://github.com/vim/vim.git --depth=1
cd vim

# TODO: Add home directory prefix path when you may don't want to install globally or you don't have sudo.

./configure --prefix=/usr/local \
            --with-features=huge \
            --enable-multibyte \
            --enable-rubyinterp \
            --enable-python3interp \
            --with-python3-config-dir="$(python3-config --configdir)" \
            --enable-perlinterp \
            --enable-luainterp \
            --enable-gui=gtk2 \
            --enable-cscope

make VIMRUNTIMEDIR=/usr/local/share/vim/vim82
sudo make install

# sudo update-alternatives --install /usr/bin/editor editor /usr/local/bin/vim 1
# sudo update-alternatives --set editor /usr/local/bin/vim
# sudo update-alternatives --install /usr/bin/vi vi /usr/local/bin/vim 1
# sudo update-alternatives --set vi /usr/local/bin/vim

