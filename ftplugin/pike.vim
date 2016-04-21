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
    if exists("g:loaded_pikedoc")
        call s:AddCommands()
    endif
    finish
endif

for src in g:pikedoc_pike_sources
    if type(src) == type({})
        let path = src['path']
    else
        let path = src
    endif

    if !isdirectory(glob(path))
        echoerr "PikeDoc: source path: ".path." does not exist."
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
        let s:{a:object}_defaults[name] = s:get_function('s:'.a:object.'_'.name)
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
    return s:plugindir."/pikedoc/pikedoc_index.txt"
endfunction

function! s:pikedoc_clear_docs() dict abort
    if isdirectory(s:plugindir."/pikedoc")
        if g:pikedoc_confirm_remove
            silent! execute "!echo 'You need to type yes to make it happen' "
                        \. "&& rm -rI ".s:plugindir."/pikedoc"
        else
            silent! execute "!rm -r ".s:plugindir."/pikedoc"
        endif
    endif
endfunction

function! s:pikedoc_generate_index() dict abort
    for src in g:pikedoc_pike_sources
        let cmd = "!".g:pikedoc_pike_cmd." "
                    \. s:plugindir."/tools/doc_extractor.pike "
                    \. "--targetdir=". s:plugindir."/pikedoc "
        if type(src) == type({})
            let cmd = cmd." --srcdir=".glob(src["path"])
            if has_key(src, 'builddir')
                let cmd = cmd." --builddir=".glob(src['builddir'])
            endif
            if has_key(src, 'imgsrc')
                let cmd = cmd." --imgsrc=".glob(src['imgsrc'])
            endif
            if has_key(src, 'imgdir')
                let cmd = cmd." --imgdir=".glob(src['imgdir'])
            endif
        else
            let cmd = cmd." --srcdir=".glob(src)
        endif

        silent! execute cmd
    endfor
    if filereadable(self.indexfile()) == 0
        throw "Unable to generate index"
    endif
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

function! s:pikedoc_make_keyword() dict abort
    let l:match = matchstr(self.cWORD,
                \'\([a-zA-Z:\.\->0-9_]*'.self.cword.'\)')
    if type(l:match) != type("")
        let self.keywords = self.cword
    else
        let self.keywords = l:match
    endif

    let namespace = matchstr(self.keywords, '^[^:]\+::')

    if len(namespace) == 0
        let namespace = "predef::"
    endif

    let self.namespace = substitute(namespace, ':', '', 'g')
    let self.keywords = substitute(self.keywords, namespace, "", "")

    let l:path = split(substitute(self.keywords,
                \'\([^`]\|^\)\(\->\|\.\|::\)', '\1 ', "g"))

    let self.path = self.namespace."/".join(l:path, "/")
    let self.keyword = l:path[-1] 
endfunction

function! s:pikedoc_find_doc() dict abort
    if len(s:index) == 0
        try
            call self.read_index()
            silent execute ":redraw!"
        catch
            silent execute ":redraw!"
            echohl ErrorMsg | echom "PikeDoc: ".v:exception | echohl None
            return 0
        endtry
    endif

    let full_path = s:plugindir."/pikedoc/".self.path
    if filereadable(full_path.".txt")
        let self.file = full_path.".txt"
        return 1
    elseif isdirectory(full_path)
        let self.file = full_path
        let self.file = self.parent()
        return 1
    endif
    let l:list = split(self.path, "/")
    if has_key(s:index, self.keyword)
        let file = get(s:index, self.keyword)
        let l:filelist = split(file, ",")
        if len(l:filelist) == 1
            let self.file = l:filelist[0]
            return 1
        elseif len(l:filelist) > 1 && len(l:list) > 1
            let subpath = join(l:list[0:-2], "/")."/".self.keyword
            let pos = match(l:filelist, subpath)
            if pos >= 0
                let self.file = l:filelist[pos]
                return 1
            endif
        endif
        if len(l:filelist)
            let choose_menu = []
            for f in l:filelist
                let choose_menu += ['*'.self.get_module_path(f).'*']
            endfor
            let self.menu = choose_menu
            let self.file = "/tmp/pikedoc_menu"
            return 1
        endif
        let self.file = file
        if isdirectory(self.file)
            self.file = self.parent()
        endif
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
    let name = "/tmp/".self.get_module_path()
    call writefile(a:content, name)
    silent execute "pedit ".name
    call delete(name)
endfunction

function! s:pikedoc_open() dict abort
    let content = []
    if filereadable(self.file)
        let content = readfile(self.file)
    elseif has_key(self, 'menu') && len(self.menu)
        let content = self.menu
    endif
    call self.fill_with(content)
endfunction

function! s:pikedoc_update_buffer() dict abort
    wincmd P
    lcd /tmp
    setlocal nobuflisted nowrap bufhidden=wipe ft=pikedoc cole=2 cocu=nc readonly nomodifiable
    nnoremap <buffer> <silent> q :bd<cr>
    execute "nnoremap <buffer> <silent> p :<C-U>call <SID>Open('".self.parent()."')<cr>"
    execute "nnoremap <buffer> <silent> m :<C-U>call <SID>Open('".self.methods()."')<cr>"
    execute "nnoremap <buffer> <silent> M :<C-U>call <SID>Open('".self.modules()."')<cr>"
    execute "nnoremap <buffer> <silent> c :<C-U>call <SID>Open('".self.classes()."')<cr>"
    execute "nnoremap <buffer> <silent> f :<C-U>call <SID>Follow()<cr>"
    execute "command! -buffer -nargs=+ -bar Search :call <SID>Search(<f-args>)"
    execute "nnoremap <buffer> s :Search "
    execute "nnoremap <buffer> S :Search ".
                \(has_key(self, "path") ?
                \substitute(fnamemodify(self.path, ":h"), '/', '.', 'g') : "").
                \"."
endfunction

function! s:pikedoc_get_name() dict abort
    return fnamemodify(self.file, ":t:r")
endfunction

function! s:pikedoc_get_module_path(...) dict abort
    if a:0
        let mpath = a:1
    else
        let mpath = self.file
    endif
    let mpath = substitute(mpath, s:plugindir."[/]*pikedoc/", "", "g")
    let mpath = substitute(mpath, "/__this__.*", "", "")
    let mpath = substitute(mpath, "/", "::", "")
    let mpath = substitute(mpath, ".txt$", "", "")
    let mpath = substitute(mpath, "/", ".", "g")
    return mpath
endfunction

function! s:pikedoc_get_this_path(what) dict abort
    let path = isdirectory(self.file) ? self.file : fnamemodify(self.file, ":h")
    let fname = fnamemodify(self.file, ":t:r")
    if fnamemodify(path, ":t:r") != "__this__"
        let path = path."/__this__/"
    endif
    if fname == "description" && a:what == "description"
        let path = path."/../../__this__/"
    endif
    let path = path."/".a:what
    if filereadable(path)
        return path
    else
        return -1
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

function! s:print(d, k)
    if has_key(a:d, a:k)
        let t = get(a:d, a:k)
        if type(t) == type([])
            let t = join(, ", ")
        endif
        echom "pikedoc ".a:k.": ".t
    endif
endfunction

function! s:pikedoc_dump() dict abort
    call s:print(self, "file")
    call s:print(self, "menu")
    call s:print(self, "cword")
    call s:print(self, "cWORD")
    call s:print(self, "namespace")
    call s:print(self, "path")
    call s:print(self, "keyword")
    call s:print(self, "keywords")
endfunction

call s:add_to('pikedoc', ['indexfile', 'generate_index', 'read_index',
            \'find_doc', 'get_name', 'open', 'parent', 'fill_with',
            \'has_doc', 'methods', 'modules', 'classes', 'get_this_path',
            \'clear_docs', 'make_keyword', 'update_buffer', 'get_module_path',
            \'dump'])

function! s:Open(...) abort
    if a:0 && a:1 == -1
        return
    endif

    let pikedoc = s:pikedoc(a:0 ? a:1 : '')

    let pikedoc.cword = expand("<cword>")
    let pikedoc.cWORD = expand("<cWORD>")
    
    if !pikedoc.has_doc()
        call pikedoc.make_keyword()
        if !pikedoc.find_doc()
            return
        endif
    endif

    call pikedoc.open()
    call pikedoc.update_buffer()
endfunction

function! s:Search(...) abort
    if !a:0
        return
    endif

    let pikedoc = s:pikedoc()

    let pikedoc.cWORD = a:1
    let pikedoc.cword = split(substitute(a:1,
                \'\([^`]\|^\)\(\->\|\.\|::\)', '\1 ', "g"))[-1]
    let pikedoc.cword = substitute(pikedoc.cword, '[^a-zA-Z0-9_]', '', 'g')
    
    call pikedoc.make_keyword()
    if !pikedoc.find_doc()
        return
    endif

    call pikedoc.open()
    call pikedoc.update_buffer()
endfunction

function! s:Follow() abort
    let pikedoc = s:pikedoc()

    let cword = matchstr(expand("<cWORD>"), '\*[^\*]\+\*')
    if len(cword)
        let cword = substitute(cword, '\*\([^*]\+\)\*.*', '\1', 'g')
        let pikedoc.cWORD = cword
        let pikedoc.cword = split(substitute(cword,
                    \'\([^`]\|^\)\(\->\|\.\|::\)', '\1 ', "g"))[-1]
        let pikedoc.cword = substitute(pikedoc.cword, '[^a-zA-Z0-9_]', '', 'g')
    else
        return
    endif

    if !pikedoc.has_doc()
        call pikedoc.make_keyword()
        if !pikedoc.find_doc()
            return
        endif
    endif

    call pikedoc.open()
    call pikedoc.update_buffer()
endfunction

function! s:Generate() abort
    let pikedoc = s:pikedoc()
    call pikedoc.clear_docs()
    try
        call pikedoc.generate_index()
        silent execute ":redraw!"
    catch /.*/
        silent execute ":redraw!"
        echohl ErrorMsg | echom "PikeDoc: ".v:exception | echohl None
    endtry
endfunction

function! s:AddCommands()
    execute "command! -buffer -nargs=0 PikeDocOpen :call s:Open()"
    execute "command! -buffer -nargs=+ PikeDocSearch :call s:Search(<f-args>)"
    execute "command! -buffer -nargs=0 PikeDocGenerate :call s:Generate()"

    if exists('g:pikedoc_define_mappings') && g:pikedoc_define_mappings == 1
        let master_key = exists('g:pikedoc_master_key') ? g:pikedoc_master_key : "g"
        execute "nnoremap <Leader>".master_key."p :PikeDocOpen<cr>"
        execute "nnoremap <Leader>".master_key."s :PikeDocSearch "
        execute "nnoremap <Leader>".master_key."g :PikeDocGenerate<cr>"
    endif
endfunction

call s:AddCommands()
