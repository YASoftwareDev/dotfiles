#!/bin/sh

# A script created to lower mental load when trying to keep up to date environment

if [ "$#" -ne 1 ]; then
  echo "\$ZSH_CUSTOM is empty or not used? Did you have zsh installed and run?"
  echo ""
  echo "Usage:"
  echo "$0 \$ZSH_CUSTOM"
  exit 2
fi

ZSH_CUSTOM=$1

echo "pull powerlevel10k"
cd $ZSH_CUSTOM/themes/powerlevel10k
git pull

echo "pull zsh-autosuggestions"
cd $ZSH_CUSTOM/plugins/zsh-autosuggestions
git pull

echo "pull zsh-syntax-highlighting"
cd $ZSH_CUSTOM/plugins/zsh-syntax-highlighting
git pull

echo "pull fast-syntax-highlighting"
cd $ZSH_CUSTOM/plugins/fast-syntax-highlighting
git pull

echo "pull tmux"
cd ~/.tmux
git pull

echo "pull fzf"
cd $(dirname $(which fzf)) && cd ..
git pull && ./install

# how often update nerdfont ?

# how to update vim

echo "would you also like to update:"
echo "ripgrep fd parallel"
echo ""

echo "Would you like to perform \"p10k configure?\""
echo ""

echo "Would you like to update vim plugins by \"vim +PluginUpdate +qall\""
echo ""

echo "Would you like to run upgrade_oh_my_zsh?"
echo ""

