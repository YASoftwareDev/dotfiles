# Dotfiles

Development environment setup for Ubuntu 20.04+.

## Quick start

### One-liner (recommended)

A profile argument is required when piping — stdin is not a terminal so the
interactive wizard cannot run.

```bash
# workstation — full setup
curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash -s -- workstation

# minimal — zsh + tmux + git config only
curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash -s -- minimal

# docker — headless, CI-friendly, no shell change
curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh | bash -s -- docker
```

Prefer to inspect before running (also enables the interactive wizard):

```bash
curl -fsSL https://raw.githubusercontent.com/YASoftwareDev/dotfiles/master/get.sh -o get.sh
bash get.sh                          # launches profile wizard
bash get.sh workstation              # or pass a profile directly
```

### Manual

```bash
git clone https://github.com/YASoftwareDev/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

Running `install.sh` without arguments launches an interactive wizard:

| Profile | What it installs | Time |
|---|---|---|
| `minimal` | zsh + oh-my-zsh, tmux, git config | ~5 min |
| `workstation` | everything: neovim, search tools, CLI utilities | ~15 min |
| `docker` | headless, CI-friendly, locale setup, no shell change | ~3 min |

Or skip the wizard:

```bash
./install.sh workstation
```

## Updating

```bash
cd ~/.dotfiles
./update.sh
```

`update.sh` updates all managed tools:
- GitHub binary releases: ripgrep, fd, shellcheck, zoxide, delta, eza, uv, neovim, cheat, ruff
- Git pull: fzf (`~/.fzf`), oh-my-zsh, zsh plugins (autosuggestions, fast-syntax-highlighting, fzf-tab), tmux plugins (resurrect, continuum, tmux-fzf, cpu)

## Repository structure

```
~/.dotfiles/
├── install.sh          # main entry point — profile wizard + runner
├── update.sh           # updater for all managed tools and plugins
├── test.sh             # integration tests
├── Dockerfile          # for testing the docker profile
│
├── lib/
│   └── utils.sh        # shared: logging, symlink, apt_install, GitHub helpers, checks
│
├── modules/
│   ├── base.sh         # apt packages + fzf shell integration
│   ├── zsh.sh          # oh-my-zsh, plugins, powerlevel10k, .zshrc symlink
│   ├── tmux.sh         # tmux config symlinks + plugin cloning
│   ├── tools.sh        # uv, ruff, cheat, ripgrep/ranger config symlinks
│   └── neovim.sh       # neovim binary install + nvim config symlink
│
├── scripts/
│   ├── install-cmake.sh # build cmake from source (optional, advanced)
│   └── install-git.sh   # build git from source (optional, advanced)
│
├── zsh/
│   └── .zshrc          # symlinked to ~/.zshrc
├── tmux/
│   ├── .tmux.conf      # gpakosz base framework (upstream, not edited)
│   └── .tmux.conf.local # local overrides — the actual config
├── nvim/
│   └── .config/nvim/
│       └── init.lua    # full neovim config (lazy.nvim, LSP, treesitter, …)
├── git/
│   ├── .gitconfig      # pager=delta, diff drivers for binary formats, delta config
│   └── .gitattributes  # diff driver assignments
├── ripgrep/
│   └── rc              # symlinked to ~/.config/ripgrep/rc
└── ranger/
    └── rc.conf …       # individual files symlinked to ~/.config/ranger/
```

## Symlink map

| Dotfile source | Installed as |
|---|---|
| `zsh/.zshrc` | `~/.zshrc` |
| `tmux/.tmux.conf` | `~/.tmux.conf` |
| `tmux/.tmux.conf.local` | `~/.tmux.conf.local` |
| `nvim/.config/nvim/` | `~/.config/nvim/` |
| `git/.gitconfig` | `~/.gitconfig` |
| `git/.gitattributes` | `~/.gitattributes` |
| `ripgrep/rc` | `~/.config/ripgrep/rc` |
| `ranger/rc.conf` etc. | `~/.config/ranger/rc.conf` etc. |

> **Note:** ranger config files are symlinked individually (not the directory) so ranger's runtime state files (bookmarks, history, tagged) are written to `~/.config/ranger/` and not tracked by git.

## What's included

### Shell & terminal

- **zsh** with **oh-my-zsh** + **powerlevel10k** prompt
- **tmux** — terminal multiplexer (gpakosz/.tmux framework)
  - Plugins: `tmux-resurrect`, `tmux-continuum`, `tmux-fzf`, `tmux-cpu`
- Oh-my-zsh plugins: `git`, `vi-mode`, `history`, `history-substring-search`, `dircycle`, `dirhistory`, `last-working-dir`, `colored-man-pages`, `command-not-found`
- External zsh plugins: `zsh-autosuggestions`, `fast-syntax-highlighting`, `fzf-tab`

### Search (the core philosophy: find anything fast)

| What | Command |
|---|---|
| Files | `Ctrl+T`, `z <dir>` |
| Content | `rg <pattern>` |
| Commands | `Ctrl+R`, autosuggestions |
| Tab completions | fzf-tab (replaces default menu) |

- **ripgrep** (`rg`) — fast content search; configured via `~/.config/ripgrep/rc`
- **fd** — fast file finder (apt installs as `fdfind`; a `fd` shim is created in `~/.local/bin`)
- **fzf** — interactive fuzzy selection; installed via git clone at `~/.fzf`; shell integration (`Ctrl+T`, `Ctrl+R`, `Alt+C` bindings + PATH) loaded from `~/.fzf.zsh` (sourced explicitly in `.zshrc`, **not** via the oh-my-zsh `fzf` plugin); `FZF_DEFAULT_COMMAND` uses ripgrep
- **zoxide** — smart directory jumper (`z <dir>`, `zi` for interactive picker)
- **eza** — modern `ls` replacement; aliased as `la` and `tree`

### Editor — Neovim

Full Lua config at `nvim/.config/nvim/init.lua`. Plugin manager: **lazy.nvim** (auto-bootstrapped).

**Stack:**
- LSP: `nvim-lspconfig` + `mason.nvim` + `mason-lspconfig` (pyright, clangd, bashls, lua_ls)
  - nvim 0.11+ API: `vim.lsp.config()` + `vim.lsp.enable()` — NOT the deprecated lspconfig setup()
- Completion: `blink.cmp` (Rust core) + `friendly-snippets`
- Treesitter: `nvim-treesitter` + textobjects + context
- Fuzzy: `telescope.nvim` + `telescope-fzf-native`
- File tree: `nvim-tree.lua` (`<F6>` to toggle); netrw still active for `:e /dir`
- Statusline: `lualine.nvim` (Nerd Font icons)
- Start screen: `dashboard-nvim` (hyper theme)
- Git: `gitsigns.nvim` + `vim-fugitive`
- Diagnostics: `trouble.nvim` (`<leader>xx`)
- Formatting: `conform.nvim` (format on save: ruff_fix+ruff_format for Python, stylua for Lua, clang-format, shfmt, prettier; disable with `NOFORMAT=1`)
- Motion: `flash.nvim` (`s`/`S` jump/treesitter, `r`/`R` remote ops)
- Writing: `zen-mode.nvim` + `twilight.nvim`
- Colorscheme: **nightfly** (default/ACTIVE) + 22 more installed, switchable via `<leader>cs`

**Key mappings (leader = Space):**
| Key | Action |
|---|---|
| `<C-p>` / `<leader>F` | Telescope find_files |
| `<leader>f` | Telescope git_files |
| `<leader>g` | Telescope live_grep |
| `<leader>b` / `<F3>` | Telescope buffers |
| `<leader>cs` | Colorscheme picker (live preview) |
| `<leader>xx` | Trouble diagnostics panel |
| `<F6>` | NvimTree toggle |
| `<F4>` | Indent guides toggle |
| `<leader>z` | Zen mode |
| `s` / `S` | flash.nvim jump / treesitter |
| `gd` / `gr` / `K` | LSP: definition / references / hover |
| `<C-h/j/k/l>`, `<M-h/j/k/l>` | Window navigation (normal + insert) |
| `<C/M-arrows>` | Window navigation (arrow key variants) |

### Git

- **delta** — pager for `git diff` / `git log` (line numbers, navigate mode, zdiff3 conflicts)
- `.gitconfig`: `pager = delta`, diff drivers for zip/gz/bz2/xz/tar/pdf/bin
- `.gitattributes`: maps file extensions to diff drivers

### Python tooling

- **uv** — fast Python package manager / virtualenv tool (installed to `~/.local/bin`)
- **uvx** — uv tool runner (installed alongside uv)
- **ruff** — Python linter + formatter (installed via `uv tool install ruff`)

### Other tools

- **ranger** — terminal file manager (config symlinked individually)
- **tig** — terminal git UI
- **cheat** — command cheatsheets (`cheat <command>`)
- **jq** — JSON processor
- **shellcheck** — shell script linter
- **GNU parallel** — parallel job execution

### Useful aliases & functions

```zsh
la          # eza -abghl (long list with icons, hidden files)
tree        # eza --tree --level=3 (directory tree)
fd          # fd -I -L (include gitignored + follow symlinks)
rgm         # rg match-only, no filename/heading (good for scripting)
stats       # sort | uniq -c | sort -n (frequency count from pipe)
ranger      # cd to last visited dir on exit
serve       # python3 -m http.server (serve current dir)
mkcd <dir>  # mkdir -p + cd
fgl         # fzf git log with git show preview
```

## Advanced install scripts

These are optional, standalone scripts for cases where the apt version is too old.
They are not called by `install.sh`.

| Script | Purpose |
|---|---|
| `scripts/install-cmake.sh` | Build CMake from source (default: 4.2.3) |
| `scripts/install-git.sh` | Build git from source (default: 2.53.0) |

Both accept an optional version argument: `./scripts/install-cmake.sh 4.1.0`

## Machine-specific config

Files not tracked by git, loaded if present:
- `~/.zshrc.local` — machine-specific zsh overrides (sourced at end of `.zshrc`)
- `~/.p10k.zsh` — powerlevel10k prompt config (generated by `p10k configure`)

## Post-install steps

```bash
exec zsh               # activate zsh (or open a new terminal)
p10k configure         # customise the prompt
nvim                   # lazy.nvim will auto-install all plugins on first launch
```
