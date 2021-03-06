".vimrc 
syntax on 

set shiftwidth=4 
set tabstop=4 
set paste
set nu
set incsearch
set hlsearch

" order is important, keep these below tabstop
set autoindent 
set smarttab
set expandtab 
set laststatus=2
set statusline+=%F\ %P

" Press Space to turn off highlighting and clear any message already displayed.
:nnoremap <silent> <Space> :nohlsearch<Bar>:echo<CR>
" center screen after search
:nnoremap n nzz
:nnoremap N Nzz
:nnoremap * *zz
:nnoremap # #zz
:nnoremap g* g*zz
:nnoremap g# g#zz
set tags=./tags,tags,/Users/marco/dev/projects/idev-selenium/tags

let perl_include_pod = 1

" Stuff I sometimes want to turn off
set ic
set smartcase
set diffopt+=iwhite
set splitright

filetype on
autocmd FileType make set nosmarttab
autocmd FileType make set noexpandtab
autocmd FileType tsv set noexpandtab
autocmd FileType csv set noexpandtab

" experimental
" let @c = 'mp{j^V}}kI# `p'
" let @u = '{j}klx`p'
"Better window navigation
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l
