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
if exists("g:loaded_pikedoc") || v:version < 700
            \ || !exists("g:pikedoc_pike_sources")
    finish
endif

for src in g:pikedoc_pike_sources
    if type(src) == type({})
        let path = src['path']
    else
        let path = src
    endif

    if !isdirectory(glob(path))
        echo "PikeDoc: source path: " . path . " does not exist."
        finish
    endif
endfor

let g:loaded_pikedoc = 1

if !exists("g:pikedoc_pike_cmd")
    let g:pikedoc_pike_cmd = 'pike'
endif

let s:plugindir = expand("<sfile>:p:h:h")
let s:index = {}

let s:protobuffer = {
            \"file" : "",
            \"name" : "",
            \"#" : -1,
            \"win#" : -1
            \}

let s:buffer = {}

function! s:get_indexfile() abort
    return s:plugindir . "/pikedoc/index.txt"
endfunction

function! s:generate_index() abort
    silent! execute "!mkdir -p " . s:plugindir . "/pikedoc/images"
    for src in g:pikedoc_pike_sources
        let cmd = "!" . g:pikedoc_pike_cmd . " "
                    \. s:plugindir . "/tools/doc_extractor.pike "
                    \. "--builddir=" .  s:plugindir . "/pikedoc"
        if type(src) == type({})
            let cmd = cmd . " --srcdir=" . glob(src["path"])
            if has_key(src, 'imgsrc')
                let cmd = cmd . " --imgsrc=" . glob(src['imgsrc'])
                let cmd = cmd . " --imgdir=" . s:plugindir . "/pikedoc/images"
            endif
        else
            let cmd = cmd . " --srcdir=" . glob(src)
        endif

        silent! execute cmd
    endfor
endfunction

function! s:read_index() abort
    let l:indexfile = s:get_indexfile()
    if filereadable(l:indexfile) == 0
        call s:generate_index()
    endif
    let local_index = readfile(l:indexfile)
    for line in local_index
        let kv = split(line)
        let s:index[kv[0]] = kv[1]
    endfor
endfunction

function! s:on_buffer_destroy() abort
    let s:buffer = extend({}, s:protobuffer)
endfunction

function! s:focus_or_create() abort
    if s:buffer['win#'] >= 0
        silent execute s:buffer['win#'] . "wincmd w"
    else
        silent execute "topleft 10new pike_doc"
        setlocal bufhidden=wipe nobuflisted noswapfile nowrap modifiable readonly
        let s:buffer['win#'] = bufwinnr('%')
        let s:buffer['#'] = bufnr('%')
        au BufDelete,BufWipeout,BufHidden <buffer> call s:on_buffer_destroy()
        nnoremap <buffer> <silent> q :bd<cr>
    endif
endfunction

function! s:load(file)
    let tmp = tempname()
    silent! execute "keepalt file " . tmp
    silent! execute "read " . a:file
    silent! normal! ggdd
    silent! w!
    let s:buffer['name'] = fnamemodify(a:file, ":t:r")
    silent execute "file " . s:buffer['name']
    set filetype=pikedoc
    call delete(tmp)
    let s:buffer['file'] = a:file
endfunction

function! s:get_helpfile(name) abort
    if len(s:index) == 0
        call s:read_index()
    endif

    let l:list = split(substitute(a:name, "\[.\]", " ", "g"))
    if len(l:list)
        let l:key = l:list[-1]
    else
        let l:key = a:name
    endif

    let l:key = substitute(l:key, "\[^a-zA-Z_0-9\]", "", "g")

    if has_key(s:index, l:key)
        let file = get(s:index, l:key)
        let l:filelist = split(file, ",")
        if len(l:filelist) && len(l:list)
            let subpath = join(l:list[0:-2], "/") . "/" . l:key
            let pos = match(l:filelist, subpath)
            if pos >= 0
                return l:filelist[pos]
            endif
        endif
        return file
    endif

    return -1
endfunction

function! s:pikedoc_open()
    let helpword = expand("<cWORD>")
    let ret = s:get_helpfile(helpword)

    if ret == -1
        return 0
    endif

    call s:focus_or_create()
    call s:load(ret)
endfunction

nnoremap <silent> <Plug>PikeDoc :<C-U>call <SID>pikedoc_open()<CR>

nmap <C-i> <Plug>PikeDoc
