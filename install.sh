#!/bin/bash

# This script should be run by
# ./install.sh

# You can tweak the install behavior by setting variables when running the script. For
# example, to install development packages:
#   DEV_PACKAGES=yes sh install.sh
#
# Respects the following environment variables:
#   DEV_PACKAGES 				- install additional developer packages 	(default: no)
#   DOCKER_SETUP 		    - install packages for docker run         (default: yes)
#   PIP_PACKAGES 				- install pip and virtualenv 							(default: no)
#   NERD_FONTS   				- clone and install nerdfonts 						(default: no)
#		UPDATE_PACKAGES			- ubuntu apt update & upgrade							(default: yes)
#		RG_PACKAGE	 				- install ripgrep 												(default: yes)
#		TMUX_PACKAGE 				- install tmux 														(default: yes)
#		FD_PACKAGE 					- install fd 															(default: yes)
#		PARALLEL_PACKAGE 		- install parallel 												(default: yes)
#		CHEAT_PACKAGE 		  - install cheat 												  (default: yes)
#		OH_MY_ZSH_PACKAGE 	- install oh-my-zsh 											(default: yes)
#		ZSH_CUSTOMIZATIONS 	- use this repo config + custom plugins 	(default: yes)
#		FZF_PACKAGE 				- install fzf 														(default: yes)
#		DIFF_SO_FANCY 			- install diff-so-fancy 									(default: yes)
#		CHANGE_SHELL 				- change shell to zsh 										(default: yes)
#		VIM_CUSTOMIZATIONS 	- use this repo config + custom plugins 	(default: yes)
#
# You can also pass some arguments to the install script to set some these options:
#   --dev: 							has the same behavior as setting DEV_PACKAGES to 'yes'
#   --no-docker-setup:  sets DOCKER_SETUP to 'no'
#   --pip: 							sets PIP_PACKAGES to 'yes'
#   --nerd: 						sets NERD_FONTS to 'yes'
#		--no-update:				set  UPDATE_PACKAGES to 'no'
#   --no-rg: 						sets RG_PACKAGE to 'no'
#		--no-tmux: 					sets TMUX_PACKAGE to 'no'
#		--no-fd: 						sets FD_PACKAGE to 'no'
#		--no-parallel: 			sets PARALLEL_PACKAGE to 'no'
#   --no-cheat:         set  CHEAT_PACKAGE to 'no'
#		--no-oh-my: 				sets OH_MY_ZSH_PACKAGE to 'no'
#		--no-custom-zsh: 		sets ZSH_CUSTOMIZATIONS to 'no'
#		--no-fzf: 					sets FZF_PACKAGE to 'no'
#		--no-diff: 					sets DIFF_SO_FANCY to 'no'
#		--no-shell-change:	sets CHANGE_SHELL to 'no'
#		--no-custom-vim: 		sets VIM_CUSTOMIZATIONS to 'no'
#
# For example:
#   sh install.sh --dev
#
# Exit immediately if a command exits with a non-zero status.
set -e

# set input variables
DEV_PACKAGES=${DEV_PACKAGES:-no}
DOCKER_SETUP=${DOCKER_SETUP:-yes}
PIP_PACKAGES=${PIP_PACKAGES:-no}
NERD_FONTS=${NERD_FONTS:-no}
UPDATE_PACKAGES=${UPDATE_PACKAGES:-yes}
RG_PACKAGE=${RG_PACKAGE:-yes}
TMUX_PACKAGE=${TMUX_PACKAGE:-yes}
FD_PACKAGE=${FD_PACKAGE:-yes}
PARALLEL_PACKAGE=${PARALLEL_PACKAGE:-yes}
CHEAT_PACKAGE=${CHEAT_PACKAGE:-yes}
OH_MY_ZSH_PACKAGE=${OH_MY_ZSH_PACKAGE:-yes}
ZSH_CUSTOMIZATIONS=${ZSH_CUSTOMIZATIONS:-yes}
FZF_PACKAGE=${FZF_PACKAGE:-yes}
DIFF_SO_FANCY=${DIFF_SO_FANCY:-yes}
CHANGE_SHELL=${CHANGE_SHELL:-yes}
VIM_CUSTOMIZATIONS=${VIM_CUSTOMIZATIONS:-yes}

# Parse input arguments
while [ $# -gt 0 ]; do
	case $1 in
		--dev) DEV_PACKAGES=yes ;;
    --no-docker-setup) DOCKER_SETUP=no ;;
		--pip) PIP_PACKAGES=yes ;;
		--nerd) NERD_FONTS=yes ;;
		--no-update) UPDATE_PACKAGES=no ;;
		--no-rg) RG_PACKAGE=no ;;
		--no-tmux) TMUX_PACKAGE=no ;;
		--no-fd) FD_PACKAGE=no ;;
		--no-parallel) PARALLEL_PACKAGE=no ;;
		--no-cheat) CHEAT_PACKAGE=no ;;
		--no-oh-my) OH_MY_ZSH_PACKAGE=no ;;
		--no-custom-zsh) ZSH_CUSTOMIZATIONS=no ;;
		--no-fzf) FZF_PACKAGE=no ;;
		--no-diff) DIFF_SO_FANCY=no ;;
		--no-shell-change) CHANGE_SHELL=no ;;
		--no-custom-vim) VIM_CUSTOMIZATIONS=no ;;
	esac
	shift
done


# Let's go to business!


# to enable execution from other directories
BASE_DIR="$(dirname $(readlink -f $0))"
cd "${BASE_DIR}"

# Let's start with getting newest stuff from apt.
if [ ${UPDATE_PACKAGES} = yes ]; then
	apt -yq update
	apt -yq upgrade
fi


# From my perspective below packages are needed only for full development environment.
# Because not all setups need them I leave you with choice based on script input argument.
if [ ${DEV_PACKAGES} = yes ]; then
	APT_PACKAGES_DEVELOPER_KIT="clang build-essential cmake python3-dev python3-pip python3-venv man-db"
	DEBIAN_FRONTEND=noninteractive apt -yq install ${APT_PACKAGES_DEVELOPER_KIT}
fi

# Install missing packages if script is run in base docker container
if [ ${DOCKER_ENV_SETUP} = yes ]; then
  APT_PACKAGES_MISSING_IN_DOCKER="locales"
	DEBIAN_FRONTEND=noninteractive apt -yq install ${APT_PACKAGES_MISSING_IN_DOCKER}
	update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
fi

# packages used by me (man for manuals, gnupg for confirm authenticity of parallel)
APT_PACKAGES_TERMINAL_ENHANCEMENTS="git curl wget vim-gtk3 tmux clipit zsh tig ranger jq fasd man gnupg"
DEBIAN_FRONTEND=noninteractive apt -yq install ${APT_PACKAGES_TERMINAL_ENHANCEMENTS}


# I'm not certain if these should be installed globally, so I leave you with choice based on script input argument
if [ ${PIP_PACKAGES} = yes ]; then
	PIP_PACKAGES_LIST="pip virtualenv"
	pip install --upgrade ${PIP_PACKAGES_LIST}
fi


# Install ripgrep (grep on steroids) and customizations
if [ ${RG_PACKAGE} = yes ]; then
	./install-ripgrep-on-ubuntu.sh
	mkdir -p ~/.config/ripgrep
	ln -s -f ${BASE_DIR}/ripgrep/rc ~/.config/ripgrep/rc
fi


# https://github.com/gpakosz/.tmux.git inspired tmux configuration. You can further adjust it later with dotfiles/tmux/ files
if [ ${TMUX_PACKAGE} = yes ]; then
	ln -s -f ${BASE_DIR}/tmux/.tmux.conf ~
	ln -s -f ${BASE_DIR}/tmux/.tmux.conf.local ~
fi


# fd - from Ubuntu 19.04 you can run: sudo apt install fd-find
# but, for now:
if [ ${FD_PACKAGE} = yes ]; then
	FD_LATEST_URL=$(curl --silent "https://api.github.com/repos/sharkdp/fd/releases/latest" | jq -r '.assets[0].browser_download_url')
	wget "${FD_LATEST_URL}"
	dpkg -i "$(basename ${FD_LATEST_URL})"
	rm "$(basename ${FD_LATEST_URL})"
fi


# Install highlight
# http://www.andre-simon.de/doku/highlight/en/install.php


# GNU parallel
# http://oletange.blogspot.com/2013/04/why-not-install-gnu-parallel.html
if [ ${PARALLEL_PACKAGE} = yes ]; then
	(wget pi.dk/3 -qO - ||  curl pi.dk/3/) | bash
fi

# cheat - allows you to create and view interactive cheatsheets on the command-line
# https://github.com/cheat/cheat
if [ ${CHEAT_PACKAGE} = yes ]; then
  ./install-cheat.sh
fi



# oh-my-zsh
if [ ${OH_MY_ZSH_PACKAGE} = yes ]; then
  wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -qO install_oh_my_zsh.sh
	sh install_oh_my_zsh.sh --unattended

fi


# enable zsh plugins and show full filepath in shell prompt
if [ ${ZSH_CUSTOMIZATIONS} = yes ]; then
	ZSH_CUSTOM=~/.oh-my-zsh/custom
	git clone git://github.com/zsh-users/zsh-autosuggestions $ZSH_CUSTOM/plugins/zsh-autosuggestions
	git clone https://github.com/zdharma/fast-syntax-highlighting.git $ZSH_CUSTOM/plugins/fast-syntax-highlighting
	git clone https://github.com/Aloxaf/fzf-tab.git $ZSH_CUSTOM/plugins/fzf-tab
	# There is also zsh-syntax-highlighting. At the moment I'm not sure which one is a winner
	#git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting

	# powerlevel10k (faster than powerlevel9k) and nerd fonts
	git clone --depth=1 https://github.com/romkatv/powerlevel10k.git $ZSH_CUSTOM/themes/powerlevel10k

	ln -s -f ${BASE_DIR}/zsh/.zshrc ~
fi


# I'm not certain that you should be forced to install nerd fonts, so I leave you with choice based on script input argument
if [ ${NERD_FONTS} = yes ]; then
	git clone --depth=1 https://github.com/ryanoasis/nerd-fonts.git ~/.nerd_fonts
	pushd ~/.nerd-fonts
	./install.sh
	popd
fi


#fzf (ctrl-R ctrl-T)
if [ ${FZF_PACKAGE} = yes ]; then
	git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
	~/.fzf/install --all
fi


#diff-so-fancy (https://github.com/so-fancy/diff-so-fancy)
if [ ${DIFF_SO_FANCY} = yes ]; then
	mkdir -p ~/.local/bin
	wget https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy -P ~/.local/bin
	git config --global core.pager "diff-so-fancy | less --tabs=4 -RFX"
	# update PATH with ~/.local/bin
fi


# Below are things Vim related. It is possible that you don't want them!
if [ ${VIM_CUSTOMIZATIONS} = yes ]; then
	ln -s -f ${BASE_DIR}/vim/.vimrc ~
	ln -s -f ${BASE_DIR}/vim/vimrc_minimal.vim ~

	# Setup vim vundle (I know that in 2020+ we have internal plugin system, but... I still didn't upgrade... )
	git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
	vim +PluginInstall +qall

# custom python folding rules for vim
#mkdir ~/.vim/syntax
#wget https://www.vim.org/scripts/download_script.php?src_id=9584

fi


if [ ${CHANGE_SHELL} = yes ]; then
	# zsh should be now default shell, if not, run below command
	chsh -s $(which zsh)
	RUN_EXTRA_COMMAND_IN_THE_END="p10k configure" zsh -i
fi


# other stuff...

#install gnu global
echo "use: https://gist.github.com/y2kr/2ff0d3e1c7f20b0925b2"
echo "check for never link (6.6.4) and later"

