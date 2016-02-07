if exists('b:did_braceless_ftplugin') | finish | endif
let b:did_braceless_ftplugin = 1

let s:jump_prev_key = get(g:, 'braceless_jump_prev_key', '[')
let s:jump_next_key = get(g:, 'braceless_jump_next_key', ']')

execute 'silent! nunmap <buffer> ['.s:jump_prev_key
execute 'silent! nunmap <buffer> ]'.s:jump_next_key
