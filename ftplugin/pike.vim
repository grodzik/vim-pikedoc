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

if !exists("g:pikedoc_confirm_remove")
    let g:pikedoc_confirm_remove = 1
endif

function! s:get_function(fun) abort
  return function(substitute(a:fun,'^s:',
              \matchstr(expand('<sfile>'), '<SNR>\d\+_'),''))
endfunction

function! s:add_to(object, what) abort
    for name in a:what
        let s:{a:object}_defaults[name] = s:get_function('s:' . a:object . '_' . name)
    endfor
endfunction

let s:plugindir = expand("<sfile>:p:h:h")
let s:index = {}

let s:pikedoc_defaults = {}

function s:pikedoc(...) abort
    let l:pikedoc = {}
    if a:0 && filereadable(a:1)
        let l:pikedoc = {'file': a:1}
    endif
    return extend(l:pikedoc, s:pikedoc_defaults)
endfunction

function! s:pikedoc_indexfile() dict abort
    return s:plugindir . "/pikedoc/index.txt"
endfunction

function! s:pikedoc_clear_docs() dict abort
    if isdirectory(s:plugindir . "/pikedoc")
        if g:pikedoc_confirm_remove
            silent! execute "!echo 'You need to type yes to make it happen' "
                        \. "&& rm -rI " . s:plugindir . "/pikedoc"
        else
            silent! execute "!rm -r " . s:plugindir . "/pikedoc"
        endif
    endif
endfunction

function! s:pikedoc_generate_index() dict abort
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

function! s:pikedoc_read_index() dict abort
    let l:indexfile = self.indexfile()
    if filereadable(l:indexfile) == 0
        call self.generate_index()
    endif
    let local_index = readfile(l:indexfile)
    for line in local_index
        let kv = split(line)
        let s:index[kv[0]] = kv[1]
    endfor
endfunction

function! s:pikedoc_find_doc(name) dict abort
    if len(s:index) == 0
        call self.read_index()
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
                let self.file = l:filelist[pos]
                return 1
            endif
        endif
        let self.file = file
        return 1
    endif

    return 0
endfunction

function! s:pikedoc_has_doc() dict abort
    if has_key(self, "file") && filereadable(self.file)
        return 1
    endif
    return 0
endfunction

function! s:pikedoc_fill_with(content) dict abort
    cd /tmp
    let name = self.get_name()
    call writefile(a:content, name)
    silent execute "pedit " . name
    call delete(name)
    cd -
endfunction

function! s:pikedoc_open() dict abort
    let content = readfile(self.file)
    call self.fill_with(content)
endfunction

function! s:pikedoc_get_name() dict abort
    return fnamemodify(self.file, ":t:r")
endfunction

function! s:pikedoc_get_this_path(what) dict abort
    let path = fnamemodify(self.file, ":h")
    if fnamemodify(path, ":t:r") != "__this__"
        let path = path."/__this__/"
    endif
    let path = path."/".a:what
    if filereadable(path)
        return path
    else
        return 0
    endif
endfunction

function! s:pikedoc_parent() dict abort
    return self.get_this_path("description")
endfunction

function! s:pikedoc_methods() dict abort
    return self.get_this_path("methods")
endfunction

function! s:pikedoc_modules() dict abort
    return self.get_this_path("modules")
endfunction

function! s:pikedoc_classes() dict abort
    return self.get_this_path("classes")
endfunction

call s:add_to('pikedoc', ['indexfile', 'generate_index', 'read_index',
            \'find_doc', 'get_name', 'open', 'parent', 'fill_with',
            \'has_doc', 'methods', 'modules', 'classes', 'get_this_path',
            \'clear_docs'])

function! s:Show(...) abort
    if a:0 && a:1 is 0
        return
    endif

    let word = a:0 ? a:1 : expand("<cWORD>")
    
    let pikedoc = s:pikedoc(word)

    if !pikedoc.has_doc()
        if !pikedoc.find_doc(word)
            return
        endif
    endif

    call pikedoc.open()

    wincmd P
    setlocal nobuflisted nowrap bufhidden=wipe
    nnoremap <buffer> <silent> q :bd<cr>
    execute "nnoremap <buffer> <silent> p :<C-U>call <SID>Show('".pikedoc.parent()."')<cr>"
    execute "nnoremap <buffer> <silent> m :<C-U>call <SID>Show('".pikedoc.methods()."')<cr>"
    execute "nnoremap <buffer> <silent> M :<C-U>call <SID>Show('".pikedoc.modules()."')<cr>"
    execute "nnoremap <buffer> <silent> c :<C-U>call <SID>Show('".pikedoc.classes()."')<cr>"
endfunction

function! s:Generate() abort
    let pikedoc = s:pikedoc()
    call pikedoc.clear_docs()
    call pikedoc.generate_index()
    silent execute ":redraw!"
endfunction

execute "command! -buffer -nargs=? PikeDoc :call s:Show(<f-args>)"
execute "command! -buffer -nargs=0 PikeDocGenerate :call s:Generate()"

if exists('g:pikedoc_define_mappings') && g:pikedoc_define_mappings == 1
    let master_key = exists('g:pikedoc_master_key') ? g:pikedoc_master_key : "g"
    execute "nnoremap <Leader>".master_key."p :PikeDoc<cr>"
    execute "nnoremap <Leader>".master_key."g :PikeDocGenerate<cr>"
endif
