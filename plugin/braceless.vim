if exists('g:loaded_braceless') && g:loaded_braceless
  finish
endif
let g:loaded_braceless = 1

vnoremap <silent> <Plug>(braceless-i-v) :<C-u>call braceless#block_op('i', 'v', visualmode(), '')<cr>
vnoremap <silent> <Plug>(braceless-a-v) :<C-u>call braceless#block_op('a', 'v', visualmode(), '')<cr>
onoremap <silent> <Plug>(braceless-i-n) :<C-u>call braceless#block_op('i', 'n', visualmode(), v:operator)<cr>
onoremap <silent> <Plug>(braceless-a-n) :<C-u>call braceless#block_op('a', 'n', visualmode(), v:operator)<cr>

let s:key = get(g:, 'braceless_key', ':')

execute 'vmap i'.s:key.' <Plug>(braceless-i-v)'
execute 'vmap a'.s:key.' <Plug>(braceless-a-v)'
execute 'omap i'.s:key.' <Plug>(braceless-i-n)'
execute 'omap a'.s:key.' <Plug>(braceless-a-n)'
