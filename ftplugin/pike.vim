"
" The MIT License (MIT)
"
" Copyright (c) 2016 Paweł Tomak <pawel@tomak.eu> and Contributors
"
" Permission is hereby granted, free of charge, to any person obtaining a copy
" of this software and associated documentation files (the "Software"), to deal
" in the Software without restriction, including without limitation the rights
" to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
" copies of the Software, and to permit persons to whom the Software is
" furnished to do so, subject to the following conditions:

" The above copyright notice and this permission notice shall be included in
" all copies or substantial portions of the Software.

" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
" IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
" FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
" AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
" LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
" OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
" THE SOFTWARE.
"
if v:version < 700 || !exists("g:pikedoc_pike_sources")
    finish
endif

execute "command! -buffer -nargs=0 PikeDocOpen :call pikedoc#open()"
execute "command! -buffer -nargs=+ PikeDocSearch :call pikedoc#search(<f-args>)"
execute "command! -buffer -nargs=0 PikeDocGenerate :call pikedoc#generate()"

if exists('g:pikedoc_define_mappings') && g:pikedoc_define_mappings == 1
    let master_key = exists('g:pikedoc_master_key') ? g:pikedoc_master_key : "g"
    execute "nnoremap <buffer> <Leader>".master_key."p :PikeDocOpen<cr>"
    execute "nnoremap <buffer> <Leader>".master_key."s :PikeDocSearch "
    execute "nnoremap <buffer> <Leader>".master_key."g :PikeDocGenerate<cr>"
endif
