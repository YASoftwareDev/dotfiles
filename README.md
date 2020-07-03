# Dotfiles

Welcome!

Here are my dotfiles tested and used on Ubuntu 18.04.

## TL;DR

```
git clone https://github.com/YASoftwareDev/dotfiles.git ~/.dotfiles
```

`~/.dotfiles/install.sh` - new installation  
`~/.dotfiles/update.sh` - update from time to time  

## TL;DR - Ubuntu 18.04 Docker

```
git clone https://github.com/YASoftwareDev/dotfiles.git ~/.dotfiles
docker run -it -e "TERM=xterm-256color" -v /home/${USER}/.dotfiles:/dotfiles ubuntu:18.04 bash -l
```
and from inside docker

```
./dotfiles/install.sh
```

## Summary

For new setups you can just run `install.sh`.

From time to time you want to update your environment to more up to date. `update.sh` is your friend then.

If you would like to install only part of possible things there are detailed explanation notes at the top of install.sh file.

Good luck and enjoy!


## A rationale behind this setup

Most important thing for me is an ability to quickly search for 3 things: files, content of a file and commands.

|  Fast search  |      Terminal       |  Vim   |
|---------------|---------------------|--------|
| Files         | CTRL+T              | :Files |
|               | fzf --preview       | CTRL+P |
|               | z                   |        |
| Files Content | rg                  | :Rg    |
| Commands      | CTRL+R              |        |
|               | CTRL+S              |        |
|               | zsh-autosuggestions |        |

## BIG batteries included

- **[zsh with oh-my-zsh setup](https://github.com/robbyrussell/oh-my-zsh)** + [autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and [syntax highlighting](https://github.com/zsh-users/zsh-syntax-highlighting).
- **[tmux](https://github.com/tmux/tmux)** - Terminal multiplexer with **[Oh My Tmux! Pretty & versatile tmux configuration made with heart](https://github.com/gpakosz/.tmux)** inspired configuration.
- **[fzf](https://github.com/junegunn/fzf)** - fzf is a general-purpose command-line fuzzy finder.
- **[ripgrep](https://github.com/BurntSushi/ripgrep)** - Ripgrep recursively searches directories for a regex pattern.
- **[fasd](https://github.com/clvv/fasd)** - Fasd (pronounced similar to "fast") is a command-line productivity booster.
- **[GNU parallel](https://www.gnu.org/software/parallel/)** - GNU parallel is a shell tool for executing jobs in parallel using one or more computers.
- **[vim](http://www.vimgolf.com/)** - Real Vim ninjas count every keystroke - do you?

## Small batteries included

- **[nerd-fonts](https://github.com/ryanoasis/nerd-fonts)** - Nerd Fonts takes popular programming fonts and adds a bunch of Glyphs.
- **[fd](https://github.com/sharkdp/fd)** - fd is a simple, fast and user-friendly alternative to find.
- **[ranger](https://github.com/ranger/ranger)** - A VIM-inspired filemanager for the console.
- **[tig](https://github.com/jonas/tig)** - Text-mode interface for Git.
- **[jq](https://github.com/stedolan/jq)** - lightweight and flexible command-line JSON processor.
- **[cheat](https://github.com/cheat/cheat)** - allows you to create and view interactive cheatsheets on the command-line


## Other goodies that you would like to have

- **[Editing long commands in your shell](https://nuclearsquid.com/writings/edit-long-commands)**

## Further readings

- [tmux cheatsheet](https://gist.github.com/MohamedAlaa/2961058)
- https://www.youtube.com/results?search_query=zsh+my+shell
- [shell configuration hack your zsh](https://blog.apptension.com/2018/08/30/shell-configuration-hack-your-zsh)
- [10 super powers for your shell](https://www.doppnet.com/10-super-powers-for-your-shell.html)


## Todo
1. Add: sudo apt-get install ruby-full (for highlight in fzf in vim).
2. Keep custom vim fzf configuration from vim.
3. Streamline thinking about installation version by providing dedicated versions for: local installation (with sudo), docker installation, installation without sudo
4. Nerd-fonts are too heavy in current script version, do something with it!
5. There are other tools like: exa. But they are not needed for everyone, what to do about it?
