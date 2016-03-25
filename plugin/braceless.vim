if exists('g:loaded_braceless') && g:loaded_braceless
  finish
endif

let s:cpo_save = &cpo
set cpo&vim

let s:base = fnamemodify(resolve(expand('<sfile>:p')), ':h:h')
let s:did_init = 0
let s:nomodline_avail = v:version > 703 || (v:version == 703 && has('patch438'))
let g:loaded_braceless = 1


let g:braceless#key#segment_prev = get(g:, 'braceless_segment_prev_key', 'k')
let g:braceless#key#segment_next = get(g:, 'braceless_segment_next_key', 'j')
let g:braceless#key#block = get(g:, 'braceless_block_key', 'P')
let g:braceless#key#jump_prev = get(g:, 'braceless_jump_prev_key', '[')
let g:braceless#key#jump_next = get(g:, 'braceless_jump_next_key', ']')
let g:braceless#key#em_prev = get(g:, 'braceless_easymotion_prev_key', g:braceless#key#jump_prev)
let g:braceless#key#em_next = get(g:, 'braceless_easymotion_next_key', g:braceless#key#jump_next)
let g:braceless#key#em_segment = get(g:, 'braceless_easymotion_segment_key', 'S')


function! s:enable(...)
  if !s:did_init
    let s:did_init = 1
    if s:nomodline_avail
      silent doautocmd <nomodeline> User BracelessInit
    else
      silent doautocmd User BracelessInit
    endif
  endif

  let b:braceless_enabled = 1

  if !empty(g:braceless#key#segment_prev) && !empty(g:braceless#key#segment_next)
    execute 'map <buffer> ['.g:braceless#key#segment_prev.' <Plug>(braceless-segment-prev-top-n)'
    execute 'map <buffer> ]'.g:braceless#key#segment_prev.' <Plug>(braceless-segment-prev-bot-n)'
    execute 'map <buffer> ['.g:braceless#key#segment_next.' <Plug>(braceless-segment-next-top-n)'
    execute 'map <buffer> ]'.g:braceless#key#segment_next.' <Plug>(braceless-segment-next-bot-n)'

    execute 'vmap <buffer> ['.g:braceless#key#segment_prev.' <Plug>(braceless-segment-prev-top-v)'
    execute 'vmap <buffer> ]'.g:braceless#key#segment_prev.' <Plug>(braceless-segment-prev-bot-v)'
    execute 'vmap <buffer> ['.g:braceless#key#segment_next.' <Plug>(braceless-segment-next-top-v)'
    execute 'vmap <buffer> ]'.g:braceless#key#segment_next.' <Plug>(braceless-segment-next-bot-v)'
  endif

  if !empty(g:braceless#key#block)
    execute 'vmap <buffer> i'.g:braceless#key#block.' <Plug>(braceless-i-v)'
    execute 'vmap <buffer> a'.g:braceless#key#block.' <Plug>(braceless-a-v)'
    execute 'omap <buffer> i'.g:braceless#key#block.' <Plug>(braceless-i-n)'
    execute 'omap <buffer> a'.g:braceless#key#block.' <Plug>(braceless-a-n)'
  endif

  if !empty(g:braceless#key#jump_prev)
    execute 'map <buffer> ['.g:braceless#key#jump_prev.' <Plug>(braceless-jump-prev-n)'
    execute 'map <buffer> g'.g:braceless#key#jump_prev.' <Plug>(braceless-jump-prev-n-indent)'
    execute 'vmap <buffer> ['.g:braceless#key#jump_prev.' <Plug>(braceless-jump-prev-v)'
    execute 'vmap <buffer> g'.g:braceless#key#jump_prev.' <Plug>(braceless-jump-prev-v-indent)'
  endif

  if !empty(g:braceless#key#jump_next)
    execute 'map <buffer> ]'.g:braceless#key#jump_next.' <Plug>(braceless-jump-next-n)'
    execute 'map <buffer> g'.g:braceless#key#jump_next.' <Plug>(braceless-jump-next-n-indent)'
    execute 'vmap <buffer> ]'.g:braceless#key#jump_next.' <Plug>(braceless-jump-next-v)'
    execute 'vmap <buffer> g'.g:braceless#key#jump_next.' <Plug>(braceless-jump-next-v-indent)'
  endif

  if get(g:, 'braceless_enable_easymotion', 1)
    if !empty(g:braceless#key#block)
      silent execute 'map <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#block.' :<C-u>call braceless#easymotion#blocks(0, 2)<cr>'
      silent execute 'xmap <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#block.' :<C-u>call braceless#easymotion#blocks(1, 2)<cr>'
    endif

    if !empty(g:braceless#key#em_prev)
      silent execute 'map <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_prev.' :<C-u>call braceless#easymotion#blocks(0, 1)<cr>'
      silent execute 'xmap <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_prev.' :<C-u>call braceless#easymotion#blocks(1, 1)<cr>'
    endif

    if !empty(g:braceless#key#em_next)
      silent execute 'map <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_next.' :<C-u>call braceless#easymotion#blocks(0, 0)<cr>'
      silent execute 'xmap <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_next.' :<C-u>call braceless#easymotion#blocks(1, 0)<cr>'
    endif

    if !empty(g:braceless#key#em_segment)
      silent execute 'map <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_segment.' :<C-u>call braceless#easymotion#segments(0, 2)<cr>'
      silent execute 'xmap <buffer> <Plug>(easymotion-prefix)'.g:braceless#key#em_segment.' :<C-u>call braceless#easymotion#segments(1, 2)<cr>'
    endif
  endif

  if !exists('b:braceless')
    let b:braceless = {}
  endif

  let b:braceless.fold_cache = {}
  let b:braceless.fold_changedtick = b:changedtick + 1
  let b:braceless.indent_enabled = 0

  call braceless#highlight#enable(0)

  if has_key(b:braceless, 'foldmethod')
    let &l:foldmethod = b:braceless.foldmethod
  endif

  if has_key(b:braceless, 'foldexpr')
    let &l:foldexpr = b:braceless.foldexpr
  endif

  if has_key(b:braceless, 'orig_cc')
    let &l:cc = b:braceless.orig_cc
  endif

  if has_key(b:braceless, 'indentexpr')
    let &l:indentexpr = b:braceless.indentexpr
  endif

  for opt in a:000
    if opt =~ '^+fold'
      if opt !~ '-slow'
        let b:braceless.foldmethod = &l:foldmethod
        call braceless#fold#enable_fast()
      else
        " Depreciated
        if opt =~ '-inner'
          let b:braceless.fold_inner = 1
        else
          let b:braceless.fold_inner = 0
        endif

        let b:braceless.foldmethod = &l:foldmethod
        let b:braceless.foldexpr = &l:foldexpr

        setlocal foldmethod=expr
        setlocal foldexpr=braceless#fold#expr(v:lnum)
      endif
    elseif opt =~ '^+highlight'
      if opt[-3:] == '-cc'
        let b:braceless.highlight_cc = 1
      elseif opt[-4:] == '-cc2'
        let b:braceless.highlight_cc = 2
      else
        let b:braceless.highlight_cc = 0
      endif
      call braceless#highlight#enable(1)
    elseif opt =~ '^+indent'
      let b:braceless.indent_enabled = 1
      let b:braceless.indentexpr = &l:indentexpr
      setlocal indentexpr=braceless#indent#expr(v:lnum)

      let setup_func = 'braceless#'.&l:filetype.'#setup_indent'
      silent! call call(setup_func, [])

      if get(g:, 'braceless_generate_scripts', 0)
        " Generate a plugin indent script that overrides indent scripts if
        " braceless was enabled from an ftplugin script.
        let indent_script = join([s:base, 'after/indent/'.&l:filetype.'.vim'], '/')
        if filewritable(fnamemodify(indent_script, ':h')) == 2 && !filereadable(indent_script)
          call writefile([
                \ 'if exists("b:braceless") && b:braceless.indent_enabled && &l:indentexpr !~ "braceless#"',
                \ '  setlocal indentexpr=braceless#indent#expr(v:lnum)',
                \ '  silent! call '.setup_func.'()',
                \ 'endif',
                \ ], indent_script)
        endif
      endif
    endif
  endfor

  execute 'silent doautocmd '.(s:nomodline_avail ? '<nomodeline>' : '').' User BracelessEnabled_'.&l:filetype
endfunction


function! s:set_highlight()
  highlight default BracelessIndent ctermfg=3 cterm=inverse guifg=#e4b65b gui=inverse
endfunction


function! s:init()
  if !exists('g:braceless_format')
    let g:braceless_format = {}
  endif

  " Text object
  vnoremap <silent> <Plug>(braceless-i-v) :<C-u>call braceless#motion#select('i', '')<cr>
  vnoremap <silent> <Plug>(braceless-a-v) :<C-u>call braceless#motion#select('a', '')<cr>
  onoremap <silent> <Plug>(braceless-i-n) :<C-u>call braceless#motion#select('i', v:operator)<cr>
  onoremap <silent> <Plug>(braceless-a-n) :<C-u>call braceless#motion#select('a', v:operator)<cr>

  " Segment movement
  noremap <silent> <Plug>(braceless-segment-prev-top-n) :<C-u>silent call braceless#segments#move(-1, 1, 'n', v:operator)<cr>
  noremap <silent> <Plug>(braceless-segment-prev-bot-n) :<C-u>silent call braceless#segments#move(-1, 0, 'n', v:operator)<cr>
  noremap <silent> <Plug>(braceless-segment-next-top-n) :<C-u>silent call braceless#segments#move( 1, 1, 'n', v:operator)<cr>
  noremap <silent> <Plug>(braceless-segment-next-bot-n) :<C-u>silent call braceless#segments#move( 1, 0, 'n', v:operator)<cr>

  vnoremap <silent> <Plug>(braceless-segment-prev-top-v) :<C-u>silent call braceless#segments#move(-1, 1, visualmode(), v:operator)<cr>
  vnoremap <silent> <Plug>(braceless-segment-prev-bot-v) :<C-u>silent call braceless#segments#move(-1, 0, visualmode(), v:operator)<cr>
  vnoremap <silent> <Plug>(braceless-segment-next-top-v) :<C-u>silent call braceless#segments#move( 1, 1, visualmode(), v:operator)<cr>
  vnoremap <silent> <Plug>(braceless-segment-next-bot-v) :<C-u>silent call braceless#segments#move( 1, 0, visualmode(), v:operator)<cr>

  " Simple block movement
  vnoremap <silent> <Plug>(braceless-jump-prev-v) :<C-u>call braceless#movement#block(-1, visualmode(), 0, v:count1)<cr>
  vnoremap <silent> <Plug>(braceless-jump-next-v) :<C-u>call braceless#movement#block(1, visualmode(), 0, v:count1)<cr>
  vnoremap <silent> <Plug>(braceless-jump-prev-v-indent) :<C-u>call braceless#movement#block(-1, visualmode(), 1, v:count1)<cr>
  vnoremap <silent> <Plug>(braceless-jump-next-v-indent) :<C-u>call braceless#movement#block(1, visualmode(), 1, v:count1)<cr>

  noremap <silent> <Plug>(braceless-jump-prev-n) :<C-u>call braceless#movement#block(-1, 'n', 0, v:count1)<cr>
  noremap <silent> <Plug>(braceless-jump-next-n) :<C-u>call braceless#movement#block(1, 'n', 0, v:count1)<cr>
  noremap <silent> <Plug>(braceless-jump-prev-n-indent) :<C-u>call braceless#movement#block(-1, 'n', 1, v:count1)<cr>
  noremap <silent> <Plug>(braceless-jump-next-n-indent) :<C-u>call braceless#movement#block(1, 'n', 1, v:count1)<cr>
endfunction


augroup braceless_plugin
  autocmd!
  autocmd User BracelessEnabled_python call braceless#python#init()
  autocmd ColorScheme * call s:set_highlight()
augroup END

call s:set_highlight()
call s:init()
command! -nargs=* BracelessEnable call s:enable(<f-args>)

let &cpo = s:cpo_save
unlet s:cpo_save
