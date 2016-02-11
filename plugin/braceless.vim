if exists('g:loaded_braceless') && g:loaded_braceless
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let g:loaded_braceless = 1


function! s:setup_easymotion()
  let next_key = get(g:, 'braceless_easymotion_next_key', ']')
  let prev_key = get(g:, 'braceless_easymotion_prev_key', '[')
  let block_key = get(g:, 'braceless_block_key', ':')

  silent execute 'map <silent> <Plug>(easymotion-prefix)'.next_key.' :<C-u>call braceless#easymotion#blocks(0, 0)<cr>'
  silent execute 'map <silent> <Plug>(easymotion-prefix)'.prev_key.' :<C-u>call braceless#easymotion#blocks(0, 1)<cr>'
  silent execute 'map <silent> <Plug>(easymotion-prefix)'.block_key.' :<C-u>call braceless#easymotion#blocks(0, 2)<cr>'
  silent execute 'xmap <silent> <Plug>(easymotion-prefix)'.next_key.' :<C-u>call braceless#easymotion#blocks(1, 0)<cr>'
  silent execute 'xmap <silent> <Plug>(easymotion-prefix)'.prev_key.' :<C-u>call braceless#easymotion#blocks(1, 1)<cr>'
  silent execute 'xmap <silent> <Plug>(easymotion-prefix)'.block_key.' :<C-u>call braceless#easymotion#blocks(1, 2)<cr>'
endfunction


function! s:init()
  let block_key = get(g:, 'braceless_block_key', ':')
  let jump_prev_key = get(g:, 'braceless_jump_prev_key', '[')
  let jump_next_key = get(g:, 'braceless_jump_next_key', ']')
  let s:callprefix = 'silent '
  if get(g:, 'braceless_dev_verbose', 0)
    let s:callprefix = ''
    set cmdheight=20
  endif

  execute "vnoremap <silent> <Plug>(braceless-i-v) :<C-u>".s:callprefix."call braceless#block_op('i', 'v', visualmode(), '')<cr>"
  execute "vnoremap <silent> <Plug>(braceless-a-v) :<C-u>".s:callprefix."call braceless#block_op('a', 'v', visualmode(), '')<cr>"
  execute "onoremap <silent> <Plug>(braceless-i-n) :<C-u>".s:callprefix."call braceless#block_op('i', 'n', visualmode(), v:operator)<cr>"
  execute "onoremap <silent> <Plug>(braceless-a-n) :<C-u>".s:callprefix."call braceless#block_op('a', 'n', visualmode(), v:operator)<cr>"

  execute "vnoremap <silent> <Plug>(braceless-jump-prev-v) :<C-u>".s:callprefix."call braceless#movement#block(-1, visualmode(), 0, v:count1)<cr>"
  execute "vnoremap <silent> <Plug>(braceless-jump-next-v) :<C-u>".s:callprefix."call braceless#movement#block(1, visualmode(), 0, v:count1)<cr>"
  execute "vnoremap <silent> <Plug>(braceless-jump-prev-v-indent) :<C-u>".s:callprefix."call braceless#movement#block(-1, visualmode(), 1, v:count1)<cr>"
  execute "vnoremap <silent> <Plug>(braceless-jump-next-v-indent) :<C-u>".s:callprefix."call braceless#movement#block(1, visualmode(), 1, v:count1)<cr>"

  execute "noremap <silent> <Plug>(braceless-jump-prev-n) :<C-u>".s:callprefix."call braceless#movement#block(-1, 'n', 0, v:count1)<cr>"
  execute "noremap <silent> <Plug>(braceless-jump-next-n) :<C-u>".s:callprefix."call braceless#movement#block(1, 'n', 0, v:count1)<cr>"
  execute "noremap <silent> <Plug>(braceless-jump-prev-n-indent) :<C-u>".s:callprefix."call braceless#movement#block(-1, 'n', 1, v:count1)<cr>"
  execute "noremap <silent> <Plug>(braceless-jump-next-n-indent) :<C-u>".s:callprefix."call braceless#movement#block(1, 'n', 1, v:count1)<cr>"

  execute 'vmap i'.block_key.' <Plug>(braceless-i-v)'
  execute 'vmap a'.block_key.' <Plug>(braceless-a-v)'
  execute 'omap i'.block_key.' <Plug>(braceless-i-n)'
  execute 'omap a'.block_key.' <Plug>(braceless-a-n)'

  execute 'map ['.jump_prev_key.' <Plug>(braceless-jump-prev-n)'
  execute 'map ]'.jump_next_key.' <Plug>(braceless-jump-next-n)'
  execute 'map g'.jump_prev_key.' <Plug>(braceless-jump-prev-n-indent)'
  execute 'map g'.jump_next_key.' <Plug>(braceless-jump-next-n-indent)'

  execute 'vmap ['.jump_prev_key.' <Plug>(braceless-jump-prev-v)'
  execute 'vmap ]'.jump_next_key.' <Plug>(braceless-jump-next-v)'
  execute 'vmap g'.jump_prev_key.' <Plug>(braceless-jump-prev-v-indent)'
  execute 'vmap g'.jump_next_key.' <Plug>(braceless-jump-next-v-indent)'


  highlight default BracelessIndent ctermfg=3 ctermbg=0 cterm=inverse

  augroup braceless
    autocmd!
    execute 'autocmd CursorMoved * '.s:callprefix.' call braceless#highlight#update(0)'
    execute 'autocmd CursorMovedI * '.s:callprefix.' call braceless#highlight#update(0)'
  augroup END

  if get(g:, 'braceless_enable_easymotion', 1)
    call s:setup_easymotion()
  endif
endfunction

call s:init()
let &cpo = s:cpo_save
unlet s:cpo_save
