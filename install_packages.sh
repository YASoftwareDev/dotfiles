#!/bin/bash

APT_PACKAGES="git vim-gtk3 curl clang build-essential cmake python3-dev python3-pip python3-venv tmux clipit zsh tig ranger jq wget man-db fasd"

PIP_PACKAGES="pip virtualenv"

# It is possible that you don't need all these packages at the moment
apt -yq update
apt -yq upgrade
apt -yq install $APT_PACKAGES

pip install --upgrade $PIP_PACKAGES

# Install ripgrep (grep on steroids)
./install-ripgrep-on-ubuntu.sh

# tmux with sane configuration. You can further adjust it later with dotfiles/tmux/ files
cd
git clone https://github.com/gpakosz/.tmux.git
ln -s -f .tmux/.tmux.conf
cp .tmux/.tmux.conf.local .

# fd - from Ubuntu 19.04 you can run: sudo apt install fd-find
# but, for now:
cd
FD_LATEST_URL=$(curl --silent "https://api.github.com/repos/sharkdp/fd/releases/latest" | jq -r '.assets[0].browser_download_url')
wget "${FD_LATEST_URL}"
dpkg -i "$(basename ${FD_LATEST_URL})"
rm "$(basename ${FD_LATEST_URL})"

# Install highlight
# http://www.andre-simon.de/doku/highlight/en/install.php

# GNU parallel
# http://oletange.blogspot.com/2013/04/why-not-install-gnu-parallel.html
(wget pi.dk/3 -qO - ||  curl pi.dk/3/) | bash

# zsh and customizations
sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"

# zsh should be now default shell, if not, run below command
# chsh -s $(which zsh)

# enable zsh plugins and show full filepath in shell prompt
git clone git://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

sed -i "s/%c/%d/g" ~/.oh-my-zsh/themes/robbyrussell.zsh-theme
sed -i "s/^plugins=.*$/plugins=(git history history-substring-search dircycle dirhistory fasd vi-mode last-working-dir zsh-autosuggestions zsh-syntax-highlighting)/g" ~/.zshrc

# powerlevel10k (faster than powerlevel9k) and nerd fonts
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

cd
git clone --depth=1 https://github.com/ryanoasis/nerd-fonts.git
cd nerd-fonts
./install.sh

#fzf (ctrl-R ctrl-T)
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install

#diff-so-fancy (https://github.com/so-fancy/diff-so-fancy)
mkdir -p ~/.local/bin
wget https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy -P ~/.local/bin
git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"


# compare your ~/.zshrc with dotfiles/zsh/.zshrc and update your configuration with proper things
echo "compare your ~/.zshrc with dotfiles/zsh/.zshrc and update your configuration with proper things"

# compare your ~/.tmux.conf with dotfiles/tmux/.tmux.conf and update your configuration with proper things
echo "compare your ~/.tmux.conf with dotfiles/tmux/.tmux.conf and update your configuration with proper things"

# compare your ~/.tmux.conf.local with dotfiles/tmux/.tmux.conf.local and update your configuration with proper things
echo "compare your ~/.tmux.conf.local with dotfiles/tmux/.tmux.conf.local and update your configuration with proper things"

# Below are things Vim related. It is possible that you don't want them!

#setup vim vundle
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim

#install gnu global
echo "use: https://gist.github.com/y2kr/2ff0d3e1c7f20b0925b2"
echo "check for never link (6.6.4) and later"

# custom python folding rules for vim
mkdir ~/.vim/syntax
wget https://www.vim.org/scripts/download_script.php?src_id=9584

#echo -e "\e[30;47mInstalling Pathogen.\e[0m"
#mkdir -p ~/.vim/autoload ~/.vim/bundle && \
#curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# compiling YCM (obsolete, we have better things now, will be updated soon)
#cd ~/.vim/bundle/YouCompleteMe;./install.py --clang-completer


