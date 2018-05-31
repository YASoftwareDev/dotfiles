#!/bin/bash

APT_PACKAGES="stow git vim-gtk3 curl fortune clang cowsay build-essential python3-dev python-pip screenfetch tmux compiz-plugins-extra clipit"

SNAP_PACKAGES="rg"

PIP_PACKAGES="pip virtualenv"

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
