if exists('b:did_indent') | finish | endif
let b:did_indent = 1

let s:cpo_save = &cpo
set cpo&vim

setlocal nolisp
setlocal tabstop=4
setlocal softtabstop=4
setlocal shiftwidth=4
setlocal shiftround
setlocal expandtab
setlocal autoindent
setlocal indentkeys=!^F,o,O,<:>,0),0],0},=elif,=except
setlocal indentexpr=braceless#indent#expr(v:lnum)


let &cpo = s:cpo_save
unlet s:cpo_save

