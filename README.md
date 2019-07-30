# Dotfiles

Welcome!

Here are my dotfiles.

If you would like to use them go line by line through install_packages.sh file, read comments and run commands.

Please do not use these files blindly! Read and use only what you really really want. Winter will come if you ignore these warnings intentionally.

If you really know what you are doing, stow is ready for you to use.

Good luck!

# A rationale behind this setup

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

# BIG batteries included

- **[zsh with oh-my-zsh setup](https://github.com/robbyrussell/oh-my-zsh)** + [autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) and [syntax highlighting](https://github.com/zsh-users/zsh-syntax-highlighting).
- **[tmux](https://github.com/gpakosz/.tmux)** - Terminal multiplexer + Oh My Tmux! Pretty & versatile tmux configuration made with heart (imho the best tmux configuration that just works).
- **[fzf](https://github.com/junegunn/fzf)** - fzf is a general-purpose command-line fuzzy finder.
- **[ripgrep](https://github.com/BurntSushi/ripgrep)** - Ripgrep recursively searches directories for a regex pattern.
- **[fasd](https://github.com/clvv/fasd)** - Fasd (pronounced similar to "fast") is a command-line productivity booster.
- **[GNU parallel](https://www.gnu.org/software/parallel/)** - GNU parallel is a shell tool for executing jobs in parallel using one or more computers.
- **[vim](http://www.vimgolf.com/)** - Real Vim ninjas count every keystroke - do you?

# Small batteries included

- **[ranger](https://github.com/ranger/ranger)** - A VIM-inspired filemanager for the console.
- **[tig](https://github.com/jonas/tig)** - Text-mode interface for Git.

# Other goodies that you would like to have

- **[Editing long commands in your shell](https://nuclearsquid.com/writings/edit-long-commands)**

# Further readings

- [tmux cheatsheet](https://gist.github.com/MohamedAlaa/2961058)
- https://www.youtube.com/results?search_query=zsh+my+shell
- [shell configuration hack your zsh](https://blog.apptension.com/2018/08/30/shell-configuration-hack-your-zsh)
- [10 super powers for your shell](https://www.doppnet.com/10-super-powers-for-your-shell.html)


# Todo
1. Change vundle to vimplug or internal plugin manager from modern Vim.
3. Add: sudo apt-get install ruby-full (for highlight in fzf in vim).
3. Add fzf installation from vim.
4. Keep custom vim fzf configuration from vim.

