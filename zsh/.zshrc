# If you come from bash you might have to change your $PATH.
export PATH=$HOME/.npm-global/bin:$HOME/bin:/usr/local/bin:$HOME/.local/bin:$HOME/.cargo/bin:$PATH:$HOME/.gem/ruby/2.5.0/bin:$HOME/Projects/ninja:$HOME/.dotnet:$HOME/.poetry/bin
export CFLAGS="-I/usr/local/boost_1_67_0/"
export RIPGREP_CONFIG_PATH=$HOME/.config/ripgrep/rc

HISTSIZE=1000000
SAVEHIST=1000000

# Path to your oh-my-zsh installation (first assume that we start from docker)
[ -d /root/.oh-my-zsh ] && export ZSH=/root/.oh-my-zsh
[ -d /home/${USER}/.oh-my-zsh ] && export ZSH=/home/${USER}/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#
DEFAULT_USER="${USER}"

POWERLEVEL9K_MODE='nerdfont-complete'
#POWERLEVEL9K_SHORTEN_DIR_LENGTH=3
#POWERLEVEL9K_SHORTEN_STRATEGY="truncate_middle"
POWERLEVEL9K_SHOW_CHANGESET=true
POWERLEVEL9K_CHANGESET_HASH_LENGTH=6
POWERLEVEL9K_PROMPT_ON_NEWLINE=true
#POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(context dir rbenv vcs)
POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(vi_mode virtualenv context dir rbenv vcs)
POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(status root_indicator background_jobs history time)
POWERLEVEL9K_VI_INSERT_MODE_STRING="I"
POWERLEVEL9K_VI_COMMAND_MODE_STRING="N"


ZSH_THEME="powerlevel10k/powerlevel10k"
#ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
#ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
#plugins=(git history history-substring-search dircycle dirhistory fasd docker vi-mode last-working-dir fzf-tab zsh-autosuggestions fast-syntax-highlighting)
plugins=(git history history-substring-search dircycle dirhistory fasd docker vi-mode last-working-dir zsh-autosuggestions fast-syntax-highlighting)

source $ZSH/oh-my-zsh.sh

# User configuration

bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC="true"

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8
export EDITOR='vim'
# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
[ -f ~/.vocab ] && ~/.vocab
eval "$(fasd --init auto)"
alias v='f -e vim'
alias rgmw='rg -No -L --no-filename --no-heading -w'
alias rgm='rg -No -L --no-filename --no-heading'
alias stats='sort --parallel=6 | uniq -c | sort -n'

alias cheat=~/.local/bin/cheat
alias ranger='ranger --choosedir=$HOME/.rangerdir; LASTDIR=`cat $HOME/.rangerdir`; cd "$LASTDIR"'

export KEYTIMEOUT=1
export GTAGSLIBPATH=$HOME/.gtags

#export BOOST_ROOT=/usr/local/boost_1_67_0
export BOOST_ROOT=/opt/boost_1_60_0/
alias :e=vim
alias gzcat=zcat
alias bzcat=zcat
alias :q=exit
alias :wq='echo "You are not in vim, dummy"'
alias la="exa -abghl --git --color=automatic"

alias fd='fd -I -L' # by default fd doesn't search gitignore files

# --files: List files that would be searched but do not search
# --no-ignore: Do not respect .gitignore, etc...
# --hidden: Search hidden files and folders
# --follow: Follow symlinks
# --glob: Additional conditions for search (in this case ignore everything in the .git/ folder)

export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
#export PAGER="most"
#export FZF_DEFAULT_OPTS='--height=70% --preview="cat {}" --preview-window=right:60%:wrap'

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
#fpath=(~/.zsh.d/ $fpath) doesn't work... :(

#. ~/Projects/ninja/misc/zsh-completion

# opam configuration (normal people seriously don't need it)
#test -r /home/${USER}/.opam/opam-init/init.zsh && . /home/${USER}/.opam/opam-init/init.zsh > /dev/null 2> /dev/null || true

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# run extra shell command from RUN variable (a bit of kludge)
eval "${RUN_EXTRA_COMMAND_IN_THE_END}"
