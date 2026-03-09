# Dotfiles

Development environment setup for Ubuntu 20.04+.

## Quick start

```bash
git clone https://github.com/YASoftwareDev/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Running `install.sh` without arguments launches an interactive wizard to pick your setup:

| Profile | What it installs | Time |
|---|---|---|
| `minimal` | zsh, tmux, git config | ~5 min |
| `workstation` | everything: editor, search tools, CLI utilities | ~15 min |
| `docker` | headless, CI-friendly, no shell change | ~3 min |

Or skip the wizard by passing the profile directly:

```bash
./install.sh workstation
```

## Updating

```bash
cd ~/.dotfiles
./update.sh
```

## What's included

**Shell & terminal**
- [zsh](https://www.zsh.org/) with [oh-my-zsh](https://ohmyz.sh/), [powerlevel10k](https://github.com/romkatv/powerlevel10k) prompt
- [tmux](https://github.com/tmux/tmux) terminal multiplexer
- [fzf](https://github.com/junegunn/fzf) — fuzzy finder (Ctrl+T, Ctrl+R)

**Search** (the core philosophy: find anything fast)

| What | Terminal | Vim |
|---|---|---|
| Files | `Ctrl+T`, `z <dir>` | `:Files`, `Ctrl+P` |
| Content | `rg <pattern>` | `:Rg` |
| Commands | `Ctrl+R`, zsh-autosuggestions | |

- [ripgrep](https://github.com/BurntSushi/ripgrep) — fast content search
- [fd](https://github.com/sharkdp/fd) — fast file finder
- [fzf](https://github.com/junegunn/fzf) — interactive fuzzy selection

**Editor & tools**
- [vim](https://www.vim.org/) with plugin stack (LSP, completion, treesitter, telescope)
- [ranger](https://github.com/ranger/ranger) — terminal file manager
- [tig](https://github.com/jonas/tig) — git UI
- [diff-so-fancy](https://github.com/so-fancy/diff-so-fancy) — better git diffs
- [cheat](https://github.com/cheat/cheat) — command cheatsheets
- [jq](https://stedolan.github.io/jq/) — JSON processor
- [GNU parallel](https://www.gnu.org/software/parallel/) — parallel job execution
- [shellcheck](https://www.shellcheck.net/) — shell script linter
