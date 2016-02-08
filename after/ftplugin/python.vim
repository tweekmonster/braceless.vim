if exists('b:did_braceless_ftplugin') | finish | endif
let b:did_braceless_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

let s:jump_prev_key = get(g:, 'braceless_jump_prev_key', '[')
let s:jump_next_key = get(g:, 'braceless_jump_next_key', ']')

call braceless#enable_folding()

execute 'silent! nunmap <buffer> ['.s:jump_prev_key
execute 'silent! nunmap <buffer> ]'.s:jump_next_key

let &cpo = s:cpo_save
unlet s:cpo_save
