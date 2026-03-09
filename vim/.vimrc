set encoding=utf-8
set nocompatible              " be iMproved, required
let mapleader = " "           " must be set before plugins and lua blocks

" Disable netrw before plugins load (required by nvim-tree)
let g:loaded_netrw       = 1
let g:loaded_netrwPlugin = 1

" The :syntax enable command will keep your current color settings.
if !exists("g:syntax_on")
  syntax enable
endif

" vim-plug first use installer
if empty(glob('~/.vim/autoload/plug.vim'))
  silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
  autocmd VimEnter * PlugInstall --sync | source $MYVIMRC
endif

call plug#begin('~/.vim/bundle')
" Colors
Plug 'jacoborus/tender.vim'

" LSP + Completion
Plug 'neovim/nvim-lspconfig'
Plug 'williamboman/mason.nvim'
Plug 'williamboman/mason-lspconfig.nvim'
Plug 'hrsh7th/nvim-cmp'
Plug 'hrsh7th/cmp-nvim-lsp'
Plug 'hrsh7th/cmp-buffer'
Plug 'hrsh7th/cmp-path'
Plug 'L3MON4D3/LuaSnip', {'tag': 'v2.*', 'do': 'make install_jsregexp'}
Plug 'saadparwaiz1/cmp_luasnip'
Plug 'rafamadriz/friendly-snippets'

" Treesitter
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'}
Plug 'nvim-treesitter/nvim-treesitter-textobjects'
Plug 'nvim-treesitter/nvim-treesitter-context'

" Langs
"Plug 'tpope/vim-markdown'
Plug 'tpope/vim-git'
Plug 'cakebaker/scss-syntax.vim'
Plug 'chrisbra/csv.vim'

" Telescope
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
Plug 'nvim-telescope/telescope-fzf-native.nvim', { 'do': 'make' }

" Tools
Plug 'tpope/vim-unimpaired'
"Plug 'broesler/jupyter-vim'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': { -> fzf#install() } }
"Plug 'gabrielelana/vim-markdown'
"Plug 'shime/vim-livedown'
Plug 'scrooloose/nerdcommenter'
Plug 'andymass/vim-matchup'
Plug 'itspriddle/ZoomWin'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'
Plug 'sjl/gundo.vim'
Plug 'tpope/vim-surround'
Plug 'dense-analysis/ale'
Plug 'RRethy/vim-illuminate'
"Plug 'scrooloose/syntastic'
Plug 'majutsushi/tagbar'
Plug 'nvim-tree/nvim-tree.lua'
Plug 'nvim-tree/nvim-web-devicons'
Plug 'michaeljsmith/vim-indent-object'
Plug 'tpope/vim-endwise'
Plug 'mattn/webapi-vim'
Plug 'mattn/gist-vim'
Plug 'Yggdroot/indentLine'
"Plug 'nathanaelkane/vim-indent-guides'
Plug 'ap/vim-css-color'
Plug 'justinmk/vim-sneak'
Plug 'chrisbra/NrrwRgn'
Plug 'lewis6991/gitsigns.nvim'
Plug 'rgarver/Kwbd.vim'
Plug 'tpope/vim-eunuch'
Plug 'romainl/vim-qlist'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-dispatch'
Plug 'thinca/vim-visualstar'
Plug 'bronson/vim-trailing-whitespace'
"Plug 'Valloric/YouCompleteMe'
"lugin 'davidhalter/jedi-vim'
Plug 'tpope/vim-obsession'
Plug 'nvim-lualine/lualine.nvim'
Plug 'rickhowe/diffchar.vim'
Plug 'jez/vim-superman'
Plug 'qpkorr/vim-bufkill'

"Other Plugs
Plug 'j-hui/fidget.nvim'
Plug 'folke/which-key.nvim'
Plug 'folke/trouble.nvim'
Plug 'stevearc/conform.nvim'
Plug 'mhinz/vim-startify'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'
Plug 'lifepillar/vim-cheat40'
Plug 'dbeniamine/cheat.sh-vim'
Plug 'tpope/vim-characterize'

" Better JSON syntax support {{{2
Plug 'elzr/vim-json', { 'for': ['javascript','json'] }

"""""""""""""""""""""""""""""""""""""" Json, show quotes (don't conceal) {{{3
let g:vim_json_syntax_conceal = 0

"Create code snippets like ~/.vim/snippets/foo.snippet
"Plug 'msanders/snipmate.vim'

call plug#end()

" ── Native LSP + Completion (nvim only) ─────────────────────────────────────
if has('nvim')
lua << EOF
-- Mason: auto-install LSP servers
require("mason").setup()
require("mason-lspconfig").setup({
  ensure_installed = { "pyright", "clangd", "bashls", "lua_ls" },
  -- automatic_enable = true is the default; mason-lspconfig calls vim.lsp.enable() for us
})

-- Snippets: load friendly-snippets (vscode-style) into LuaSnip
require("luasnip.loaders.from_vscode").lazy_load()

-- Completion setup
local cmp     = require("cmp")
local luasnip = require("luasnip")

cmp.setup({
  snippet = {
    expand = function(args) luasnip.lsp_expand(args.body) end,
  },
  mapping = cmp.mapping.preset.insert({
    ['<C-Space>'] = cmp.mapping.complete(),
    ['<C-e>']     = cmp.mapping.abort(),
    ['<CR>']      = cmp.mapping.confirm({ select = true }),
    ['<Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then cmp.select_next_item()
      elseif luasnip.expand_or_jumpable() then luasnip.expand_or_jump()
      else fallback() end
    end, { 'i', 's' }),
    ['<S-Tab>'] = cmp.mapping(function(fallback)
      if cmp.visible() then cmp.select_prev_item()
      elseif luasnip.jumpable(-1) then luasnip.jump(-1)
      else fallback() end
    end, { 'i', 's' }),
  }),
  sources = cmp.config.sources(
    { { name = 'nvim_lsp' }, { name = 'luasnip' } },
    { { name = 'buffer' },   { name = 'path' } }
  ),
})

-- LSP keymaps (active only in buffers with an attached LSP server)
local on_attach = function(_, bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set('n', 'gd',         vim.lsp.buf.definition,     vim.tbl_extend('force', opts, { desc = 'Go to definition' }))
  vim.keymap.set('n', 'gD',         vim.lsp.buf.declaration,    vim.tbl_extend('force', opts, { desc = 'Go to declaration' }))
  vim.keymap.set('n', 'gr',         vim.lsp.buf.references,     vim.tbl_extend('force', opts, { desc = 'References' }))
  vim.keymap.set('n', 'gi',         vim.lsp.buf.implementation, vim.tbl_extend('force', opts, { desc = 'Go to implementation' }))
  vim.keymap.set('n', 'K',          vim.lsp.buf.hover,          vim.tbl_extend('force', opts, { desc = 'Hover docs' }))
  vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename,         vim.tbl_extend('force', opts, { desc = 'Rename symbol' }))
  vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action,    vim.tbl_extend('force', opts, { desc = 'Code action' }))
  vim.keymap.set('n', '<leader>d',  vim.diagnostic.open_float,  vim.tbl_extend('force', opts, { desc = 'Show diagnostics' }))
  vim.keymap.set('n', '[d', function() vim.diagnostic.jump({ count = -1 }) end, vim.tbl_extend('force', opts, { desc = 'Prev diagnostic' }))
  vim.keymap.set('n', ']d', function() vim.diagnostic.jump({ count =  1 }) end, vim.tbl_extend('force', opts, { desc = 'Next diagnostic' }))
end

-- Advertise cmp capabilities to each server
local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- nvim 0.11+: use vim.lsp.config instead of deprecated require('lspconfig').xxx.setup()
-- lspconfig plugin still provides default cmd/filetypes/root_markers via runtimepath
vim.lsp.config('pyright', { capabilities = capabilities, on_attach = on_attach })
vim.lsp.config('clangd',  { capabilities = capabilities, on_attach = on_attach })
vim.lsp.config('bashls',  { capabilities = capabilities, on_attach = on_attach })
vim.lsp.config('lua_ls',  {
  capabilities = capabilities,
  on_attach    = on_attach,
  settings = {
    Lua = {
      runtime    = { version = 'LuaJIT' },
      workspace  = { library = vim.api.nvim_get_runtime_file('', true), checkThirdParty = false },
      diagnostics = { globals = { 'vim' } },
    },
  },
})
vim.lsp.enable({ 'pyright', 'clangd', 'bashls', 'lua_ls' })

-- Diagnostics display
vim.diagnostic.config({
  virtual_text    = true,
  signs           = true,
  underline       = true,
  update_in_insert = false,
  severity_sort   = true,
})
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Conform (auto-format on save) ───────────────────────────────────────────
if has('nvim')
lua << EOF
require('conform').setup({
  formatters_by_ft = {
    python     = { 'isort', 'black' },
    cpp        = { 'clang_format' },
    c          = { 'clang_format' },
    sh         = { 'shfmt' },
    bash       = { 'shfmt' },
    javascript = { 'prettier' },
    json       = { 'prettier' },
  },
  format_on_save = function(bufnr)
    if vim.env.NOFORMAT then return end
    return { timeout_ms = 500, lsp_format = "fallback" }
  end,
})
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Trouble ─────────────────────────────────────────────────────────────────
if has('nvim')
lua << EOF
require('trouble').setup()
EOF
nnoremap <leader>xx <cmd>Trouble diagnostics toggle<cr>
nnoremap <leader>xb <cmd>Trouble diagnostics toggle filter.buf=0<cr>
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Gitsigns ────────────────────────────────────────────────────────────────
if has('nvim')
lua << EOF
require('gitsigns').setup({
  signs = {
    add          = { text = '▎' },
    change       = { text = '▎' },
    delete       = { text = '▁' },
    topdelete    = { text = '▔' },
    changedelete = { text = '▎' },
  },
  on_attach = function(bufnr)
    local gs   = package.loaded.gitsigns
    local opts = { buffer = bufnr, silent = true }
    vim.keymap.set('n', ']h', gs.next_hunk,                                           vim.tbl_extend('force', opts, { desc = 'Next hunk' }))
    vim.keymap.set('n', '[h', gs.prev_hunk,                                           vim.tbl_extend('force', opts, { desc = 'Prev hunk' }))
    vim.keymap.set('n', '<leader>hs', gs.stage_hunk,                                  vim.tbl_extend('force', opts, { desc = 'Stage hunk' }))
    vim.keymap.set('n', '<leader>hu', gs.undo_stage_hunk,                             vim.tbl_extend('force', opts, { desc = 'Undo stage hunk' }))
    vim.keymap.set('n', '<leader>hp', gs.preview_hunk,                                vim.tbl_extend('force', opts, { desc = 'Preview hunk' }))
    vim.keymap.set('n', '<leader>hb', function() gs.blame_line({ full = true }) end,  vim.tbl_extend('force', opts, { desc = 'Blame line' }))
    vim.keymap.set('n', '<leader>hB', gs.toggle_current_line_blame,                   vim.tbl_extend('force', opts, { desc = 'Toggle inline blame' }))
    vim.keymap.set('n', '<leader>hd', gs.diffthis,                                    vim.tbl_extend('force', opts, { desc = 'Diff this' }))
  end,
})
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Lualine ─────────────────────────────────────────────────────────────────
if has('nvim')
lua << EOF
require('lualine').setup({
  options = {
    theme    = 'auto',
    icons_enabled = true,
    component_separators = { left = '', right = '' },
    section_separators   = { left = '', right = '' },
  },
  sections = {
    lualine_a = { 'mode' },
    lualine_b = { 'branch', 'diff', 'diagnostics' },
    lualine_c = { { 'filename', path = 1 } },
    lualine_x = { 'encoding', 'fileformat', 'filetype' },
    lualine_y = { 'progress' },
    lualine_z = { 'location' },
  },
})
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Nvim-tree ───────────────────────────────────────────────────────────────
if has('nvim')
lua << EOF
require('nvim-tree').setup()
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Telescope ───────────────────────────────────────────────────────────────
if has('nvim')
lua << EOF
local telescope = require('telescope')
local actions   = require('telescope.actions')

telescope.setup({
  defaults = {
    mappings = {
      i = {
        ['<C-j>'] = actions.move_selection_next,
        ['<C-k>'] = actions.move_selection_previous,
        ['<Esc>'] = actions.close,
      },
    },
    file_ignore_patterns = { '%.git/', 'node_modules/', '__pycache__/', '%.o', '%.a' },
    vimgrep_arguments = {
      'rg', '--color=never', '--no-heading', '--with-filename',
      '--line-number', '--column', '--smart-case', '--hidden',
    },
  },
  pickers = {
    find_files   = { hidden = true },
    live_grep    = { additional_args = function() return { '--hidden' } end },
  },
})
telescope.load_extension('fzf')
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Fidget (LSP progress) ────────────────────────────────────────────────────
if has('nvim')
lua << EOF
require('fidget').setup()
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Which-key ───────────────────────────────────────────────────────────────
if has('nvim')
lua << EOF
require("which-key").setup()
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Treesitter context ───────────────────────────────────────────────────────
if has('nvim')
lua << EOF
require('treesitter-context').setup({ max_lines = 3 })
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

" ── Treesitter ───────────────────────────────────────────────────────────────
" nvim-treesitter was fully rewritten for nvim 0.10+; nvim-treesitter.configs
" is gone. Highlighting is native via vim.treesitter; textobjects use new API.
if has('nvim')
lua << EOF
-- Install parsers (async, idempotent no-op if already present)
require('nvim-treesitter').install({
  'python', 'cpp', 'c', 'bash', 'lua', 'vim', 'json', 'javascript'
})

-- Enable built-in treesitter highlighting per filetype
-- augroup with clear=true prevents duplicate autocmds on :so $MYVIMRC
vim.api.nvim_create_autocmd('FileType', {
  group    = vim.api.nvim_create_augroup('UserTreesitter', { clear = true }),
  pattern  = { 'python', 'cpp', 'c', 'bash', 'lua', 'vim', 'json', 'javascript' },
  callback = function() pcall(vim.treesitter.start) end,
})

-- Textobjects: select (x = visual, o = operator-pending)
local sel = require('nvim-treesitter-textobjects.select')
local sel_maps = {
  af = '@function.outer', ['if'] = '@function.inner',
  ac = '@class.outer',    ic    = '@class.inner',
  aa = '@parameter.outer', ia   = '@parameter.inner',
}
for lhs, query in pairs(sel_maps) do
  vim.keymap.set({ 'x', 'o' }, lhs,
    function() sel.select_textobject(query, 'textobjects') end,
    { desc = query })
end

-- Textobjects: move
local mv = require('nvim-treesitter-textobjects.move')
vim.keymap.set('n', ']f', function() mv.goto_next_start('@function.outer',     'textobjects') end, { desc = 'Next function' })
vim.keymap.set('n', ']c', function() mv.goto_next_start('@class.outer',        'textobjects') end, { desc = 'Next class' })
vim.keymap.set('n', '[f', function() mv.goto_previous_start('@function.outer', 'textobjects') end, { desc = 'Prev function' })
vim.keymap.set('n', '[c', function() mv.goto_previous_start('@class.outer',    'textobjects') end, { desc = 'Prev class' })
EOF
endif
" ────────────────────────────────────────────────────────────────────────────

"set background=dark
":set t_Co=256
"let g:solarized_termcolors=256

" If you have vim >=8.0 or Neovim >= 0.1.5
if (has("termguicolors"))
 set termguicolors
endif

" Theme
syntax enable
colorscheme tender

"try
"  colorscheme wombat256
"catch
"endtry
"colorscheme bclear

" highlight current line
au WinLeave * set nocursorline nocursorcolumn
au WinEnter * set cursorline cursorcolumn

"set backupdir=~/.vim/backup// " set custom directory for backup
"set directory=~/.vim/swp// " set custom directory for swap
"set highlight 	    " conflict with highlight current line
"set listchars=eol:¬,tab:>·,trail:~,extends:>,precedes:<,space:␣
set autoindent      " always set autoindenting on
set backspace=indent,eol,start " allow backspacing over everything in insert mode
set copyindent      " copy the previous indentation on autoindenting
set cursorcolumn    " highlight current column
set cursorline      " highlight current line
set hidden          " allowing background buffers without save
set history=1000    " remember more commands and search history
set hlsearch        " highlight search terms
set ignorecase      " ignore case when searching
set incsearch       " show search matches as you type
set infercase       " Smart casing when completing
set list            " Show invisible characters
set listchars=tab:\ \             " a tab should display as "  ", trailing whitespace as "."
set listchars+=trail:.,extends:>,precedes:<
set matchpairs+=<:> " specially for html
set matchtime=2     " show matching bracket for 0.2 seconds
set mouse=a         " allowing mouse access
set nobackup        " disable backup
set noerrorbells    " don't beep
set noswapfile      " disable swap
set wrap            " wrap lines
set number          " always show line numbers
"set pastetoggle=<F2>
set relativenumber  " line numbering relative to current line
set scrolloff=5     " 5 lines above/below cursor when scrolling
set shiftround      " use multiple of shiftwidth when indenting with '<' and '>'
set showmatch       " set show matching parenthesis
set smartcase       " ignore case if search pattern is all lowercase, case-sensitive otherwise
set tabstop=2       " a tab are two spaces
set softtabstop=2   " the number of spaces to use when expanding tabs
set expandtab       " expand tabs
set smarttab        " insert tabs on the start of a line according to shiftwidth, not tabstop
set shiftwidth=2    " number of spaces to use for autoindenting
set title           " change the terminal's title
set undolevels=1000 " use many muchos levels of undo
set undofile                      " persist undo history across sessions
set undodir=~/.vim/undodir        " store undo files here
set visualbell      " don't beep
set wildignore+=*/.git/*,*/tmp/*,*.swp,*.so,*.o,*.a,*.obj,*.bak,*.zip,*.pyc,*.pyo,*.class,.DS_Store  " MacOSX/Linux
set wildmenu
"set wildmode=longest,full,full
"set wildmode=longest,list
set wildmode=list:longest
"set wildmode=full,longest:full
"set wildmode=list:longest,longest:full

set wildcharm=<C-z>
"nnoremap ,e :e **/*<C-z><S-Tab>
"nnoremap ,e :e **/*<C-z>
nnoremap ,e <cmd>Telescope find_files<CR>

nmap <F3> <cmd>Telescope buffers<CR>
nmap <F4> :IndentLinesToggle<cr>
nmap <F5> :TagbarToggle<cr>
nmap <F6> :NvimTreeToggle<cr>
" Easy window navigation
" Alt+leftarrow will go one window left, etc.
nmap [1;3A :execute 'wincmd k'<CR>
nmap [1;5A :execute 'wincmd k'<CR>
nmap [1;3B :execute 'wincmd j'<CR>
nmap [1;5B :execute 'wincmd j'<CR>
nmap [1;3D :execute 'wincmd h'<CR>
nmap [1;5D :execute 'wincmd h'<CR>
nmap [1;3C :execute 'wincmd l'<CR>
nmap [1;5C :execute 'wincmd l'<CR>
nmap <C-k> :execute 'wincmd k'<CR>
nmap <C-j> :execute 'wincmd j'<CR>
nmap <C-h> :execute 'wincmd h'<CR>
nmap <C-l> :execute 'wincmd l'<CR>
nmap k :execute 'wincmd k'<CR>
nmap j :execute 'wincmd j'<CR>
nmap h :execute 'wincmd h'<CR>
nmap l :execute 'wincmd l'<CR>
"nmap <silent> <A-Up> :execute 'wincmd k'<CR>
"nmap <silent> <A-Down> :execute 'wincmd j'<CR>
"nmap <silent> <A-Left> :execute 'wincmd h'<CR>
"nmap <silent> <A-Right> :execute 'wincmd l'<CR>
imap <C-l> <ESC><c-w>l
imap <C-h> <ESC><c-w>h
imap <C-k> <ESC><c-w>k
imap <C-j> <ESC><c-w>j
"imap l <ESC><c-w>l
"imap h <ESC><c-w>h
"imap k <ESC><c-w>k
"imap j <ESC><c-w>j
imap <C-Right> <ESC><c-w>l
imap <C-Left> <ESC><c-w>h
imap <C-Up> <ESC><c-w>k
imap <C-Down> <ESC><c-w>j
imap <M-Right> <ESC><c-w>l
imap <M-Left> <ESC><c-w>h
imap <M-Up> <ESC><c-w>k
imap <M-Down> <ESC><c-w>j
" quickly resize windows with a vertical split:
:map - <C-W>-
:map + <C-W>+


"clearing highlighted searches
nmap <silent> <leader>/ :nohlsearch<CR>


" Additional customization
"imap ii <Esc>`^
nnoremap Y y$
"
" w!! to sudo & write a file
cmap w!! %!sudo tee >/dev/null %

" Quickly edit/reload the vimrc file
nmap <silent> <leader>ev :e $MYVIMRC<CR>
nmap <silent> <leader>sv :so $MYVIMRC<CR>

" eggcache vim
:command! W w
:command! WQ wq
:command! Wq wq
:command! Q q
:command! Qa qa
:command! QA qa


" open file in split
map gs :above wincmd f<CR>
map gv :vertical wincmd f<CR>





" Tagbar configuration
let g:tagbar_usearrows = 1
let g:tagbar_autofocus = 1
nnoremap <leader>l :TagbarToggle<CR>



" indentline

let g:indentLine_char_list = ['|', '¦', '┆', '┊']
let g:indentLine_fileTypeExclude = ['json', 'markdown', 'csv', 'help', 'startify']



" Replaced grep engine for CtrlP to really faster one
if executable('rg')
  set grepprg=rg\ --vimgrep
  set grepformat=%f:%l:%c:%m,%f:%l:%m
endif




function! GotoJump()
    jumps
    let j = input("Please select your jump: ")
    if j != ''
        let pattern = '\v\c^\+'
        if j =~ pattern
            let j = substitute(j, pattern, '', 'g')
            execute "normal " . j . "\<c-i>"
        else
            execute "normal " . j . "\<c-o>"
        endif
    endif
endfunction

nmap <Leader>j :call GotoJump()<CR>

"so /usr/local/share/gtags/gtags.vim

autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!

map f <Plug>Sneak_f
map F <Plug>Sneak_F
map t <Plug>Sneak_t
map T <Plug>Sneak_T

" Ale configuration
" Disabled for LSP-covered filetypes to avoid duplicate diagnostics
let g:ale_linters = {
\   'python': [],
\   'cpp':    [],
\   'c':      [],
\   'sh':     [],
\}
let g:ale_disable_lsp = 1
let g:ale_sign_column_always = 1
let g:ale_sign_error = '✗'
let g:ale_sign_warning = '⚠'
" Disabled: trouble.nvim handles diagnostics panel now
let g:ale_set_loclist = 0
let g:ale_set_quickfix = 0
let g:ale_open_list = 0


" telescope ------------------------------
nnoremap <silent> <C-p>      <cmd>Telescope find_files<CR>
nmap <Leader>f               <cmd>Telescope git_files<CR>
nmap <Leader>F               <cmd>Telescope find_files<CR>
nmap <Leader>g               <cmd>Telescope live_grep<CR>
nmap <Leader>G               <cmd>Telescope grep_string<CR>
nmap <Leader>b               <cmd>Telescope buffers<CR>
nmap <Leader>s               <cmd>Telescope lsp_document_symbols<CR>
nmap <Leader>S               <cmd>Telescope lsp_workspace_symbols<CR>
nmap <Leader>lr              <cmd>Telescope lsp_references<CR>

" https://stackoverflow.com/questions/62148994/strange-character-since-last-update-42m-in-vim
" It was a problem of modifyOtherKeys. After looking at the doc, putting
if exists("&t_TI")
  let &t_TI = ""
endif
if exists("&t_TE")
  let &t_TE = ""
endif
