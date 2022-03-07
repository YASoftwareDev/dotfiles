set encoding=utf-8
set nocompatible              " be iMproved, required

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
Plug 'vim-scripts/Colour-Sampler-Pack'
Plug 'altercation/vim-colors-solarized'
Plug 'tpope/vim-vividchalk'
Plug 'vim-scripts/molokai'
Plug 'vim-scripts/pyte'
Plug 'telamon/vim-color-github'
Plug 'larssmit/vim-getafe'
Plug 'TechnoGate/janus-colors'
Plug 'chriskempson/vim-tomorrow-theme'
Plug 'chriskempson/base16-vim'
Plug 'carakan/new-railscasts-theme'
Plug 'jacoborus/tender.vim'

" Langs
Plug 'pangloss/vim-javascript'
"Plug 'tpope/vim-markdown'
Plug 'tpope/vim-git'
Plug 'cakebaker/scss-syntax.vim'
Plug 'chrisbra/csv.vim'

" Tools
Plug 'tpope/vim-unimpaired'
"Plug 'broesler/jupyter-vim'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'
"Plug 'gabrielelana/vim-markdown'
"Plug 'shime/vim-livedown'
Plug 'scrooloose/nerdcommenter'
Plug 'andymass/vim-matchup'
Plug 'itspriddle/ZoomWin'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rhubarb'
Plug 'sjl/gundo.vim'
Plug 'tpope/vim-surround'
Plug 'MarcWeber/vim-addon-mw-utils'
Plug 'dense-analysis/ale'
Plug 'RRethy/vim-illuminate'
"Plug 'scrooloose/syntastic'
Plug 'majutsushi/tagbar'
Plug 'scrooloose/nerdtree'
Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'michaeljsmith/vim-indent-object'
Plug 'tpope/vim-endwise'
Plug 'mattn/webapi-vim'
Plug 'mattn/gist-vim'
Plug 'Yggdroot/indentLine'
"Plug 'nathanaelkane/vim-indent-guides'
Plug 'ap/vim-css-color'
Plug 'Lokaltog/vim-easymotion'
Plug 'justinmk/vim-sneak'
Plug 'chrisbra/NrrwRgn'
Plug 'jeetsukumaran/vim-buffergator'
Plug 'airblade/vim-gitgutter'
Plug 'rgarver/Kwbd.vim'
Plug 'tpope/vim-eunuch'
Plug 'romainl/vim-qlist'
" I don't really know if I need below plugin
Plug 'tpope/vim-repeat'
" the same with below one
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
Plug 'tpope/vim-dispatch'
Plug 'thinca/vim-visualstar'
Plug 'bronson/vim-trailing-whitespace'
"Plug 'Valloric/YouCompleteMe'
"lugin 'davidhalter/jedi-vim'
Plug 'tpope/vim-obsession'
Plug 'vim-airline/vim-airline'
Plug 'pseewald/vim-anyfold'
Plug 'arecarn/vim-fold-cycle'
Plug 'rickhowe/diffchar.vim'
Plug 'tiagofumo/vim-nerdtree-syntax-highlight'
Plug 'prabirshrestha/async.vim'
Plug 'prabirshrestha/vim-lsp'
Plug 'jez/vim-superman'
Plug 'qpkorr/vim-bufkill'

"Other Plugs
Plug 'mhinz/vim-startify'
Plug 'junegunn/goyo.vim'
Plug 'junegunn/limelight.vim'
Plug 'lifepillar/vim-cheat40'
Plug 'dbeniamine/cheat.sh-vim'
Plug 'wincent/command-t'
Plug 'rafi/awesome-vim-colorschemes'
Plug 'ryanoasis/vim-devicons'
Plug 'tpope/vim-characterize'

" Better JSON syntax support {{{2
Plug 'elzr/vim-json', { 'for': ['javascript','json'] }

"""""""""""""""""""""""""""""""""""""" Json, show quotes (don't conceal) {{{3
let g:vim_json_syntax_conceal = 0

"Create code snippets like ~/.vim/snippets/foo.snippet
"Plug 'msanders/snipmate.vim'

call plug#end()

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

let g:airline_theme = 'tender'

"try
"  colorscheme wombat256
"catch
"endtry
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

" indentline

let g:indentLine_char_list = ['|', '¦', '┆', '┊']

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

"so /usr/local/share/gtags/gtags.vim

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

let g:ale_set_loclist = 0
let g:ale_set_quickfix = 1

let g:ale_open_list = 1

let g:ale_list_window_size = 5
"let g:ale_echo_cursor = 0 " there is an issue with ale cursor visibility in my vim version. You need to uprade vim to newer version.

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

" fzf ------------------------------

nnoremap <silent> <C-p> :Files<CR>
nmap <Leader>f :GFiles<CR>
nmap <Leader>F :Files<CR>

"below lines taken from:
"https://github.com/junegunn/fzf.vim

" Command for git grep
" - fzf#vim#grep(command, with_column, [options], [fullscreen])
command! -bang -nargs=* GGrep
  \ call fzf#vim#grep(
  \   'git grep --line-number '.shellescape(<q-args>), 0,
  \   fzf#vim#with_preview({'dir': systemlist('git rev-parse --show-toplevel')[0]}), <bang>0)

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

" vim-markdown configuration
let g:markdown_enable_folding = 1

" https://stackoverflow.com/questions/62148994/strange-character-since-last-update-42m-in-vim
" It was a problem of modifyOtherKeys. After looking at the doc, putting
if exists("&t_TI")
  let &t_TI = ""
endif
if exists("&t_TE")
  let &t_TE = ""
endif
