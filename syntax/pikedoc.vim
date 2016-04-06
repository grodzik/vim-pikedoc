" Vim syntax file
" Language:	Pike documentation
" Maintainer:	Paweł Tomak <pawel@tomak.eu>

" Quit when a (custom) syntax file was already loaded
if exists("b:current_syntax")
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

syn match helpHeadline		"^[A-Z][A-Za-z ]\+$"
syn match helpSectionDelim	"^===.*===$"
syn match helpSectionDelim	"^---.*--$"
if has("conceal")
  syn region helpExample	matchgroup=helpIgnore start=" >$" start="^>$" end="^[^ \t]"me=e-1 end="^<" concealends
else
  syn region helpExample	matchgroup=helpIgnore start=" >$" start="^>$" end="^[^ \t]"me=e-1 end="^<"
endif
if has("ebcdic")
  syn match helpHyperTextEntry	"\\\@<!\*[^"*|]\+\*" contains=helpStar
  syn match helpHyperTextEntry	"\*[^"*|]\+\*\s"he=e-1 contains=helpStar
  syn match helpHyperTextEntry	"\*[^"*|]\+\*$" contains=helpStar
else
  syn match helpHyperTextEntry	"\\\@<!\*[#-)!+-~]\+\*" contains=helpStar
  syn match helpHyperTextEntry	"\*[#-)!+-~]\+\*\s"he=e-1 contains=helpStar
  syn match helpHyperTextEntry	"\*[#-)!+-~]\+\*$" contains=helpStar
endif
if has("conceal")
  syn match helpStar		contained "\*" conceal
else
  syn match helpStar		contained "\*"
endif
if has("conceal")
  syn match helpIgnore		"." contained conceal
else
  syn match helpIgnore		"." contained
endif
syn match helpURL `\v<(((https?|ftp|gopher)://|(mailto|file|news):)[^' 	<>"]+|(www|web|w3)[a-z0-9_-]*\.[a-z0-9._-]+\.[^' 	<>"]+)[a-zA-Z0-9/]`

" Additionally load a language-specific syntax file "help_ab.vim".
let s:i = match(expand("%"), '\.\a\ax$')
if s:i > 0
  exe "runtime syntax/help_" . strpart(expand("%"), s:i + 1, 2) . ".vim"
endif

syn sync minlines=40

" Define the default highlighting.
" Only used when an item doesn't have highlighting yet
hi def link helpIgnore		Ignore
hi def link helpHyperTextJump	Identifier
hi def link helpStar		Ignore
hi def link helpHyperTextEntry	String
hi def link helpHeadline	Statement
hi def link helpSectionDelim	PreProc
hi def link helpIdentifier	Identifier

let b:current_syntax = "help"

let &cpo = s:cpo_save
unlet s:cpo_save
" vim: ts=8 sw=2
