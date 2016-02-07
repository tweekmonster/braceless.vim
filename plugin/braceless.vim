if exists('g:loaded_braceless') && g:loaded_braceless
  finish
endif
let g:loaded_braceless = 1

function! s:init()
  let block_key = get(g:, 'braceless_block_key', ':')
  let jump_prev_key = get(g:, 'braceless_jump_prev_key', '[')
  let jump_next_key = get(g:, 'braceless_jump_next_key', ']')
  let callprefix = 'silent '
  if get(g:, 'braceless_dev_verbose', 0)
    let callprefix = ''
    set cmdheight=20
  endif

  execute "vnoremap <silent> <Plug>(braceless-i-v) :<C-u>".callprefix."call braceless#block_op('i', 'v', visualmode(), '')<cr>"
  execute "vnoremap <silent> <Plug>(braceless-a-v) :<C-u>".callprefix."call braceless#block_op('a', 'v', visualmode(), '')<cr>"
  execute "onoremap <silent> <Plug>(braceless-i-n) :<C-u>".callprefix."call braceless#block_op('i', 'n', visualmode(), v:operator)<cr>"
  execute "onoremap <silent> <Plug>(braceless-a-n) :<C-u>".callprefix."call braceless#block_op('a', 'n', visualmode(), v:operator)<cr>"
  execute "vnoremap <silent> <Plug>(braceless-jump-prev-v) :<C-u>".callprefix."call braceless#block_jump(-1, visualmode(), v:count1)<cr>"
  execute "vnoremap <silent> <Plug>(braceless-jump-next-v) :<C-u>".callprefix."call braceless#block_jump(1, visualmode(), v:count1)<cr>"
  execute "noremap <silent> <Plug>(braceless-jump-prev-n) :<C-u>".callprefix."call braceless#block_jump(-1, 'n', v:count1)<cr>"
  execute "noremap <silent> <Plug>(braceless-jump-next-n) :<C-u>".callprefix."call braceless#block_jump(1, 'n', v:count1)<cr>"

  execute 'vmap i'.block_key.' <Plug>(braceless-i-v)'
  execute 'vmap a'.block_key.' <Plug>(braceless-a-v)'
  execute 'omap i'.block_key.' <Plug>(braceless-i-n)'
  execute 'omap a'.block_key.' <Plug>(braceless-a-n)'

  execute 'map ['.jump_prev_key.' <Plug>(braceless-jump-prev-n)'
  execute 'map ]'.jump_next_key.' <Plug>(braceless-jump-next-n)'
  execute 'vmap ['.jump_prev_key.' <Plug>(braceless-jump-prev-v)'
  execute 'vmap ]'.jump_next_key.' <Plug>(braceless-jump-next-v)'
endfunction

call s:init()
