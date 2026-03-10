# Enable Powerlevel10k instant prompt. Must stay near the top.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ── PATH ──────────────────────────────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/bin:/usr/local/bin:$PATH"

# ── History ───────────────────────────────────────────────────────────────────
HISTSIZE=1000000
SAVEHIST=1000000
setopt inc_append_history
setopt share_history
setopt hist_ignore_dups
setopt hist_ignore_space
setopt hist_expire_dups_first  # when trimming, remove dups before unique entries
setopt hist_find_no_dups       # Ctrl+R / history search skips duplicate entries

# ── oh-my-zsh ─────────────────────────────────────────────────────────────────
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# zsh-autosuggestions config must be set before oh-my-zsh loads the plugin
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_USE_ASYNC="true"
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=180'
COMPLETION_WAITING_DOTS="true"

plugins=(
  git
  colored-man-pages
  command-not-found
  history
  history-substring-search
  dircycle
  dirhistory
  vi-mode
  last-working-dir
  fzf
  fzf-tab
  zsh-autosuggestions
  fast-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# ── Environment ───────────────────────────────────────────────────────────────
export LANG=en_US.UTF-8
export EDITOR=nvim
export VISUAL=nvim

export RIPGREP_CONFIG_PATH="$HOME/.config/ripgrep/rc"

# ── Key bindings ──────────────────────────────────────────────────────────────
bindkey "^[[1;5C" forward-word
bindkey "^[[1;5D" backward-word
bindkey -a 'V' edit-command-line
export KEYTIMEOUT=1

# ── zoxide (z <dir> to jump, zi for interactive picker) ──────────────────────
# Guarded: only init if zoxide is installed (it's installed by install.sh)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# ── fzf ───────────────────────────────────────────────────────────────────────
export FZF_DEFAULT_COMMAND='rg --files --no-ignore --hidden --follow --glob "!.git/*"'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# ── fzf-tab completion ────────────────────────────────────────────────────────
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' menu no
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza --color=always -1 $realpath 2>/dev/null || ls --color=always -1 $realpath 2>/dev/null'
zstyle ':fzf-tab:*' switch-group '<' '>'

# ── Aliases ───────────────────────────────────────────────────────────────────
# fd: search everything including gitignored and hidden by default
alias fd='fd -I -L'

# ripgrep convenience
alias rgm='rg -No -L --no-filename --no-heading'
alias rgmw='rg -No -L --no-filename --no-heading -w'

# quick frequency count: cmd | stats
alias stats='sort --parallel=6 | uniq -c | sort -n'

# ranger: return to last visited directory on exit (graceful fallback if ranger crashes)
alias ranger='ranger --choosedir="$HOME/.rangerdir"; cd "$(cat "$HOME/.rangerdir" 2>/dev/null || echo .)"'

# serve current directory over HTTP
alias serve='python3 -m http.server'

# eza: modern ls (only if installed)
if command -v eza &>/dev/null; then
  alias la='eza -abghl --color=automatic'
  alias tree='eza --tree --level=3 --color=always --group-directories-first'
fi

# ── Functions ─────────────────────────────────────────────────────────────────
mkcd() { mkdir -p "$1" && cd "$1"; }

fgl() {
  git log --oneline --color=always \
    | fzf --ansi --preview 'git show --color=always {1}' \
    | awk '{print $1}'
}

# ── Powerlevel10k ─────────────────────────────────────────────────────────────
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

[[ $TMUX == "" ]] && export TERM="xterm-256color"

# ── Local overrides (machine-specific, not tracked) ───────────────────────────
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
