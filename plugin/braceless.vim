if exists('g:loaded_braceless') && g:loaded_braceless
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let g:loaded_braceless = 1


let g:braceless#key#block = get(g:, 'braceless_block_key', ':')
let g:braceless#key#jump_prev = get(g:, 'braceless_jump_prev_key', '[')
let g:braceless#key#jump_next = get(g:, 'braceless_jump_next_key', ']')
let g:braceless#key#em_prev = get(g:, 'braceless_easymotion_prev_key', g:braceless#key#jump_prev)
let g:braceless#key#em_next = get(g:, 'braceless_easymotion_next_key', g:braceless#key#jump_next)


function! s:enable()
  let b:braceless_enabled = 1

  execute 'vmap <buffer> i'.g:braceless#key#block.' <Plug>(braceless-i-v)'
  execute 'vmap <buffer> a'.g:braceless#key#block.' <Plug>(braceless-a-v)'
  execute 'omap <buffer> i'.g:braceless#key#block.' <Plug>(braceless-i-n)'
  execute 'omap <buffer> a'.g:braceless#key#block.' <Plug>(braceless-a-n)'

  execute 'map <buffer> ['.g:braceless#key#jump_prev.' <Plug>(braceless-jump-prev-n)'
  execute 'map <buffer> ]'.g:braceless#key#jump_next.' <Plug>(braceless-jump-next-n)'
  execute 'map <buffer> g'.g:braceless#key#jump_prev.' <Plug>(braceless-jump-prev-n-indent)'
  execute 'map <buffer> g'.g:braceless#key#jump_next.' <Plug>(braceless-jump-next-n-indent)'

  execute 'vmap <buffer> ['.g:braceless#key#jump_prev.' <Plug>(braceless-jump-prev-v)'
  execute 'vmap <buffer> ]'.g:braceless#key#jump_next.' <Plug>(braceless-jump-next-v)'
  execute 'vmap <buffer> g'.g:braceless#key#jump_prev.' <Plug>(braceless-jump-prev-v-indent)'
  execute 'vmap <buffer> g'.g:braceless#key#jump_next.' <Plug>(braceless-jump-next-v-indent)'

  if get(g:, 'braceless_enable_easymotion', 1)
    silent execute 'map <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_next.' :<C-u>call braceless#easymotion#blocks(0, 0)<cr>'
    silent execute 'map <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_prev.' :<C-u>call braceless#easymotion#blocks(0, 1)<cr>'
    silent execute 'map <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#block.' :<C-u>call braceless#easymotion#blocks(0, 2)<cr>'
    silent execute 'xmap <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_next.' :<C-u>call braceless#easymotion#blocks(1, 0)<cr>'
    silent execute 'xmap <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_prev.' :<C-u>call braceless#easymotion#blocks(1, 1)<cr>'
    silent execute 'xmap <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#block.' :<C-u>call braceless#easymotion#blocks(1, 2)<cr>'
  endif
endfunction


function! s:init()
  vnoremap <silent> <Plug>(braceless-i-v) :<C-u>call braceless#block_op('i', 'v', visualmode(), '')<cr>
  vnoremap <silent> <Plug>(braceless-a-v) :<C-u>call braceless#block_op('a', 'v', visualmode(), '')<cr>
  onoremap <silent> <Plug>(braceless-i-n) :<C-u>call braceless#block_op('i', 'n', visualmode(), v:operator)<cr>
  onoremap <silent> <Plug>(braceless-a-n) :<C-u>call braceless#block_op('a', 'n', visualmode(), v:operator)<cr>

  vnoremap <silent> <Plug>(braceless-jump-prev-v) :<C-u>call braceless#movement#block(-1, visualmode(), 0, v:count1)<cr>
  vnoremap <silent> <Plug>(braceless-jump-next-v) :<C-u>call braceless#movement#block(1, visualmode(), 0, v:count1)<cr>
  vnoremap <silent> <Plug>(braceless-jump-prev-v-indent) :<C-u>call braceless#movement#block(-1, visualmode(), 1, v:count1)<cr>
  vnoremap <silent> <Plug>(braceless-jump-next-v-indent) :<C-u>call braceless#movement#block(1, visualmode(), 1, v:count1)<cr>

  noremap <Plug>(braceless-jump-prev-n) :<C-u>call braceless#movement#block(-1, 'n', 0, v:count1)<cr>
  noremap <Plug>(braceless-jump-next-n) :<C-u>call braceless#movement#block(1, 'n', 0, v:count1)<cr>
  noremap <Plug>(braceless-jump-prev-n-indent) :<C-u>call braceless#movement#block(-1, 'n', 1, v:count1)<cr>
  noremap <Plug>(braceless-jump-next-n-indent) :<C-u>call braceless#movement#block(1, 'n', 1, v:count1)<cr>

  highlight default BracelessIndent ctermfg=3 ctermbg=0 cterm=inverse

  command! BracelessEnable :call s:enable()
  command! BracelessHighlightToggle :call braceless#highlight#toggle()
  command! BracelessHighlightEnable :call braceless#highlight#enable(1)
  command! BracelessHighlightDisable :call braceless#highlight#enable(0)
endfunction

call s:init()
let &cpo = s:cpo_save
unlet s:cpo_save
