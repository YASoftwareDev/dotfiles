set encoding=utf-8
set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'
" Colors
Plugin 'vim-scripts/Colour-Sampler-Pack'
Plugin 'altercation/vim-colors-solarized'
Plugin 'tpope/vim-vividchalk'
Plugin 'vim-scripts/molokai'
Plugin 'vim-scripts/pyte'
Plugin 'telamon/vim-color-github'
Plugin 'larssmit/vim-getafe'
Plugin 'TechnoGate/janus-colors'
Plugin 'chriskempson/vim-tomorrow-theme'
Plugin 'chriskempson/base16-vim'
Plugin 'railscasts'

" Langs
Plugin 'pangloss/vim-javascript'
"Plugin 'tpope/vim-markdown'
Plugin 'tpope/vim-git'
Plugin 'cakebaker/scss-syntax.vim'
Plugin 'chrisbra/csv.vim'

" Tools
Plugin 'tpope/vim-unimpaired'
"Plugin 'broesler/jupyter-vim'
Plugin 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plugin 'junegunn/fzf.vim'
"Plugin 'gabrielelana/vim-markdown'
"Plugin 'shime/vim-livedown'
Plugin 'scrooloose/nerdcommenter'
Plugin 'andymass/vim-matchup'
Plugin 'itspriddle/ZoomWin'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-rhubarb'
Plugin 'sjl/gundo.vim'
Plugin 'tpope/vim-surround'
Plugin 'MarcWeber/vim-addon-mw-utils'
Plugin 'w0rp/ale'
Plugin 'RRethy/vim-illuminate'
"Plugin 'scrooloose/syntastic'
Plugin 'majutsushi/tagbar'
Plugin 'scrooloose/nerdtree'
Plugin 'Xuyuanp/nerdtree-git-plugin'
Plugin 'michaeljsmith/vim-indent-object'
Plugin 'tpope/vim-endwise'
Plugin 'mattn/webapi-vim'
Plugin 'mattn/gist-vim'
Plugin 'nathanaelkane/vim-indent-guides'
Plugin 'ap/vim-css-color'
Plugin 'Lokaltog/vim-easymotion'
Plugin 'justinmk/vim-sneak'
Plugin 'chrisbra/NrrwRgn'
Plugin 'jeetsukumaran/vim-buffergator'
Plugin 'airblade/vim-gitgutter'
Plugin 'rgarver/Kwbd.vim'
Plugin 'tpope/vim-eunuch'
Plugin 'romainl/vim-qlist'
" I don't really know if I need below plugin
Plugin 'tpope/vim-repeat'
" the same with below one
Plugin 'SirVer/ultisnips'
Plugin 'honza/vim-snippets'
Plugin 'tpope/vim-dispatch'
Plugin 'thinca/vim-visualstar'
Plugin 'bronson/vim-trailing-whitespace'
"Plugin 'Valloric/YouCompleteMe'
"lugin 'davidhalter/jedi-vim'
Plugin 'tpope/vim-obsession'
Plugin 'vim-airline/vim-airline'
Plugin 'pseewald/vim-anyfold'
Plugin 'arecarn/vim-fold-cycle'
Plugin 'rickhowe/diffchar.vim'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'tiagofumo/vim-nerdtree-syntax-highlight'
Plugin 'prabirshrestha/async.vim'
Plugin 'prabirshrestha/vim-lsp'

"Other Plugins
Plugin 'mhinz/vim-startify'
Plugin 'junegunn/goyo.vim'
Plugin 'junegunn/limelight.vim'
Plugin 'lifepillar/vim-cheat40'
Plugin 'dbeniamine/cheat.sh-vim'
Plugin 'wincent/command-t'
Plugin 'rafi/awesome-vim-colorschemes'
Plugin 'ryanoasis/vim-devicons'
Plugin 'tpope/vim-characterize'
"Create code snippets like ~/.vim/snippets/foo.snippet
"Plugin 'msanders/snipmate.vim'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:

syntax on
"set background=dark
":set t_Co=256
"let g:solarized_termcolors=256
colorscheme wombat256
"colorscheme bclear
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size = 1
let mapleader = " "  "\ is the default leader character


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
set lazyredraw      " don't update the display while executing macros
set list            " Show invisible characters
set listchars=tab:\ \             " a tab should display as "  ", trailing whitespace as "."
set listchars+=trail:.,extends:>,precedes:<
set matchpairs+=<:> " specially for html
set matchtime=2     " show matching bracket for 0.2 seconds
set mouse=a         " allowing mouse access
set nobackup        " disable backup
set noerrorbells    " don't beep
set noswapfile      " disable swap
set nowrap          " don't wrap lines
set number          " always show line numbers
set pastetoggle=<F2>
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
set visualbell      " don't beep
set wildignore+=*/.git/*,*/tmp/*,*.swp,*.so,*.o,*.a,*.obj,*.bak,*.zip,*.pyc,*.pyo,*.class,.DS_Store  " MacOSX/Linux
set wildmenu
"set wildmode=longest,full,full
"set wildmode=longest,list
set wildmode=list:longest
"set wildmode=full,longest:full
"set wildmode=list:longest,longest:full
set wrap

set wildcharm=<C-z>
"nnoremap ,e :e **/*<C-z><S-Tab>
"nnoremap ,e :e **/*<C-z>
nnoremap ,e :Files<CR>

nmap <F3> :Buffers<CR>
nmap <F4> :IndentGuidesToggle<cr>
nmap <F5> :TagbarToggle<cr>
nmap <F6> :NERDTreeToggle<cr>
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

" up/down with linewrap
nnoremap <expr> j v:count ? (v:count > 5 ? "m'" . v:count : '') . 'j' : 'gj'
nnoremap <expr> k v:count ? (v:count > 5 ? "m'" . v:count : '') . 'k' : 'gk'

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
:command W w
:command WQ wq
:command Wq wq
:command Q q
:command Qa qa
:command QA qa


" open file in split
map gs :above wincmd f<CR>
map gv :vertical wincmd f<CR>

" Go to definition for YouCompleteMe Plugin Python language
"nnoremap <leader>gg :YcmCompleter GoToDefinitionElseDeclaration<CR>
"nnoremap <leader>gd :YcmCompleter GetDoc<CR>
"let g:ycm_python_binary_path = 'python'
let g:ycm_add_preview_to_completeopt = 1
let g:ycm_autoclose_preview_window_after_completion = 1
let g:ycm_autoclose_preview_window_after_insertion = 1

let g:ycm_key_list_select_completion = ['<C-j>']
let g:ycm_key_list_previous_completion = ['<C-k>']

let g:UltiSnipsExpandTrigger = "<C-l>"
let g:UltiSnipsJumpForwardTrigger = "<C-j>"
let g:UltiSnipsJumpBackwardTrigger = "<C-k>"
let g:UltiSnipsExpandTrigger="<c-j>"


" Activated smarter tab line in airline plugin
let g:airline#extensions#tabline#enabled = 1
let g:airline_powerline_fonts = 1
"let g:webdevicons_enable_airline_tabline = 1

" vim-anyfold plugin configuration
" let anyfold_activate = 1
" set foldlevel=0

" Tagbar configuration
let g:tagbar_usearrows = 1
let g:tagbar_autofocus = 1
nnoremap <leader>l :TagbarToggle<CR>

" NERDTree  ------------------------------
nmap <Leader>n :NERDTreeToggle<CR>
nmap <Leader>N :NERDTreeFind<CR>
let NERDTreeMinimalUI = 1
let NERDTreeDirArrows = 1
let NERDTreeQuitOnOpen = 0

" ctrlp ----------------------------------
let g:ctrlp_custom_ignore = '\.git$\|\.hg$\|\.svn$'
nmap <leader>gf :CtrlP<CR><C-\>w

" Syntastic ------------------------------


" show list of errors and warnings on the current file
nmap <leader>e :Errors<CR>
" check also when just opened the file
let g:syntastic_check_on_open = 1
" don't put icons on the sign column (it hides the vcs status icons of signify)
let g:syntastic_enable_signs = 1
" custom icons (enable them if you use a patched font, and enable the previous 
" setting)
let g:syntastic_error_symbol = '✗'
let g:syntastic_warning_symbol = '⚠'
let g:syntastic_style_error_symbol = '✗'
let g:syntastic_style_warning_symbol = '⚠'

" Jedi-vim ------------------------------

" All these mappings work only for python code:
" Go to definition
let g:jedi#goto_command = '<leader>d'
" Find ocurrences
let g:jedi#usages_command = '<leader>o'
" Find assignments
let g:jedi#goto_assignments_command = '<leader>a'
" Go to definition in new tab
nmap <leader>D :tab split<CR>:call jedi#goto()<CR>

" buffergator configuration
" Leader-b opens buffers list (other options in documentation)

" Replaced grep engine for CtrlP to really faster one
if executable('rg')
"  set grepprg=rg\ --vimgrep\ --no-heading
  set grepprg=rg\ --vimgrep
  set grepformat=%f:%l:%c:%m,%f:%l:%m

  let g:ctrlp_user_command = 'rg %s --files --color=never --glob ""'
  let g:ctrlp_use_caching = 0
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

so /usr/local/share/gtags/gtags.vim

autocmd! User GoyoEnter Limelight
autocmd! User GoyoLeave Limelight!

let g:webdevicons_enable = 1
let g:WebDevIconsUnicodeDecorateFolderNodes = 1
"let g:DevIconsEnableFoldersOpenClose = 1
"
map f <Plug>Sneak_f
map F <Plug>Sneak_F
map t <Plug>Sneak_t
map T <Plug>Sneak_T

" Ale configuration
let g:ale_sign_column_always = 1
let g:ale_sign_error = '✗'
let g:ale_sign_warning = '⚠'
let g:airline#extensions#ale#enabled = 1
let g:ale_set_quickfix = 1
let g:ale_open_list = 1
let g:ale_echo_cursor = 0 " there is an issue with ale cursor visibility in my vim version. You need to uprade vim to newer version.

nmap <silent> <leader>aj :ALENext<cr>
nmap <silent> <leader>ak :ALEPrevious<cr>

if executable('clangd')
    augroup lsp_clangd
        autocmd!
        autocmd User lsp_setup call lsp#register_server({
                    \ 'name': 'clangd',
                    \ 'cmd': {server_info->['clangd']},
                    \ 'whitelist': ['c', 'cpp', 'objc', 'objcpp'],
                    \ })
        autocmd FileType c setlocal omnifunc=lsp#complete
        autocmd FileType cpp setlocal omnifunc=lsp#complete
        autocmd FileType objc setlocal omnifunc=lsp#complete
        autocmd FileType objcpp setlocal omnifunc=lsp#complete
    augroup end
endif

"below lines taken from:
"https://github.com/junegunn/fzf.vim

" Command for git grep
" - fzf#vim#grep(command, with_column, [options], [fullscreen])
command! -bang -nargs=* GGrep
  \ call fzf#vim#grep(
  \   'git grep --line-number '.shellescape(<q-args>), 0,
  \   { 'dir': systemlist('git rev-parse --show-toplevel')[0] }, <bang>0)

" Override Colors command. You can safely do this in your .vimrc as fzf.vim
" will not override existing commands.
command! -bang Colors
  \ call fzf#vim#colors({'left': '15%', 'options': '--reverse --margin 5%,0'}, <bang>0)

" --column: Show column number
" --line-number: Show line number
" --no-heading: Do not show file headings in results
" --fixed-strings: Search term as a literal string
" --ignore-case: Case insensitive search
" --no-ignore: Do not respect .gitignore, etc...
" --hidden: Search hidden files and folders
" --follow: Follow symlinks
" --glob: Additional conditions for search (in this case ignore everything in the .git/ folder)
" --color: Search color options

command! -bang -nargs=* Find call fzf#vim#grep('rg --column --line-number --no-heading --fixed-strings --ignore-case --no-ignore --hidden --follow --glob "!.git/*" --color "always" '.shellescape(<q-args>), 1, <bang>0)

" Similarly, we can apply it to fzf#vim#grep. To use ripgrep instead of ag:
command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always --smart-case '.shellescape(<q-args>), 1,
  \   <bang>0 ? fzf#vim#with_preview('up:60%')
  \           : fzf#vim#with_preview('right:50%:hidden', '?'),
  \   <bang>0)

" Likewise, Files command with preview window
command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

" vim-markdown configuration
let g:markdown_enable_folding = 1
