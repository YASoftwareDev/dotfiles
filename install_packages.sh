#!/bin/bash

APT_PACKAGES="stow git vim-gtk3 curl fortune clang cowsay build-essential python3-dev python-pip python3-venv screenfetch tmux compiz-plugins-extra clipit zsh tig ranger cheat"

SNAP_PACKAGES="rg"

PIP_PACKAGES="pip virtualenv sudocabulary"

echo -e "\e[30;47mInstalling apt packages.\e[0m"
apt update
apt -y install $APT_PACKAGES
apt upgrade

echo -e "\e[30;47mInstalling snap packages.\e[0m"
apt update
apt -y install $APT_PACKAGES
apt upgrade

echo -e "\e[30;47mInstalling pip packages.\e[0m"
pip install --upgrade $PIP_PACKAGES

echo -e "\e[30;47mInstalling pip packages.\e[0m"
pip install --upgrade $PIP_PACKAGES

#echo -e "\e[30;47mInstalling Pathogen.\e[0m"
#mkdir -p ~/.vim/autoload ~/.vim/bundle && \
#curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# zsh and customizations
sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

git clone git://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting


# setup zsh as default shell (needed logout)
chsh -s $(which zsh)

# tmux
cd
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local .


# powerlevel9k and nerd fonts
git clone --depth=1 https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k

cd
git clone --depth=1 https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts
./install.sh

# fasd (check if current release is supported)
sudo add-apt-repository ppa:aacebedo/fasd
sudo apt-get update
sudo apt-get install fasd


#setup vim vundle

git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

#install gnu global
echo "use: https://gist.github.com/y2kr/2ff0d3e1c7f20b0925b2"
echo "check for never link (6.6.4) and later"

# custom python folding rules for vim
mkdir ~/.vim/syntax
wget https://www.vim.org/scripts/download_script.php?src_id=9584
