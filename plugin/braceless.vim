if exists('g:loaded_braceless') && g:loaded_braceless
  finish
endif
let g:loaded_braceless = 1

vnoremap <silent> <Plug>(braceless-i-v) :<C-u>call braceless#block_op('i', 'v', visualmode(), '')<cr>
vnoremap <silent> <Plug>(braceless-a-v) :<C-u>call braceless#block_op('a', 'v', visualmode(), '')<cr>
onoremap <silent> <Plug>(braceless-i-n) :<C-u>call braceless#block_op('i', 'n', visualmode(), v:operator)<cr>
onoremap <silent> <Plug>(braceless-a-n) :<C-u>call braceless#block_op('a', 'n', visualmode(), v:operator)<cr>
vnoremap <silent> <Plug>(braceless-jump-prev-v) :<C-u>call braceless#block_jump(-1, visualmode(), v:count1)<cr>
vnoremap <silent> <Plug>(braceless-jump-next-v) :<C-u>call braceless#block_jump(1, visualmode(), v:count1)<cr>
noremap <silent> <Plug>(braceless-jump-prev-n) :<C-u>call braceless#block_jump(-1, 'n', v:count1)<cr>
noremap <silent> <Plug>(braceless-jump-next-n) :<C-u>call braceless#block_jump(1, 'n', v:count1)<cr>

let s:block_key = get(g:, 'braceless_block_key', ':')
let s:jump_prev_key = get(g:, 'braceless_jump_prev_key', '[')
let s:jump_next_key = get(g:, 'braceless_jump_next_key', ']')

execute 'vmap i'.s:block_key.' <Plug>(braceless-i-v)'
execute 'vmap a'.s:block_key.' <Plug>(braceless-a-v)'
execute 'omap i'.s:block_key.' <Plug>(braceless-i-n)'
execute 'omap a'.s:block_key.' <Plug>(braceless-a-n)'

execute 'map ['.s:jump_prev_key.' <Plug>(braceless-jump-prev-n)'
execute 'map ]'.s:jump_next_key.' <Plug>(braceless-jump-next-n)'
execute 'vmap ['.s:jump_prev_key.' <Plug>(braceless-jump-prev-v)'
execute 'vmap ]'.s:jump_next_key.' <Plug>(braceless-jump-next-v)'
