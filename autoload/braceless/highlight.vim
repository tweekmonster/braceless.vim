function! s:highlight_line(line1, line2)
  let use_cc = get(g:, 'braceless_highlight_use_cc', 0)
  if !exists('s:origcc')
    let s:origcc = &cc
  endif

  if a:line1 < 1
    if use_cc
      let &cc = s:origcc
    endif

    call s:mark_column(0, 0, 0)
    return
  endif

  let [_, indent_len] = braceless#indent#space(a:line1, 0)

  if use_cc > 0
    let &cc = s:origcc.','.(indent_len+1)
    if use_cc == 1
      return
    endif
  endif

  call s:mark_column(a:line1, a:line2, indent_len)
endfunction


function! s:mark_column(line1, line2, column)
  if exists('b:braceless_column')
    for id in b:braceless_column
      silent! call matchdelete(id)
    endfor
    unlet b:braceless_column
    silent! unlet w:braceless_highlight_cache
  endif

  if a:line1 == 0
    return
  endif

  if a:line2 - a:line1 < 1
    return
  endif

  let matches = []
  for i in range(a:line1 + 1, a:line2, 8)
    let group = []
    for j in range(0, 7)
      let c_line = i + j

      if c_line > a:line2
        break
      endif

      if a:column == 0 && col([c_line, '$']) < 2
        continue
      endif

      call add(group, [c_line, a:column + 1, 1])
    endfor

    let id = matchaddpos('BracelessIndent', group, 90)
    call add(matches, id)
  endfor

  let b:braceless_column = matches
endfunction


" Enable/disable block highlighting on a per-buffer basis
function! braceless#highlight#enable(b)
  let b:braceless_enable_highlight = a:b
  if a:b
    call braceless#highlight#update(1)

    augroup braceless_highlight
      autocmd! * <buffer>
      autocmd CursorMoved,CursorMovedI <buffer> call braceless#highlight#update(0)
      autocmd WinEnter,BufEnter <buffer> call braceless#highlight#update(1)
      autocmd WinLeave,BufLeave <buffer> call s:mark_column(0, 0, 0)
    augroup END
  else
    call s:mark_column(0, 0, 0)

    augroup braceless_highlight
      autocmd! * <buffer>
    augroup END
  endif
endfunction


function! braceless#highlight#toggle()
  call braceless#highlight#enable(!get(b:, 'braceless_enable_highlight', 0))
endfunction


" Highlight indent block
function! braceless#highlight#update(force)
  if !get(b:, 'braceless_enable_highlight', 0)
    return
  endif

  let l = line('.')
  let [pattern, _] = braceless#get_pattern()
  let pblock = search('^\s*'.pattern, 'ncbW')
  let indent_level = braceless#indent#level(pblock, 0)

  if !a:force && exists('w:braceless_highlight_cache')
    let c = w:braceless_highlight_cache
    if pblock == c[0] && indent_level == c[1] && l >= c[2][0] && l <= c[2][1]
      return
    endif
  endif

  let block = braceless#get_block_lines(line('.'))
  if type(block) != 3
    return
  endif

  if l < block[0] || l > block[1]
    call s:mark_column(0, 0, 0)
    return
  endif

  let w:braceless_highlight_cache = [pblock, indent_level, block]
  call s:highlight_line(block[0], block[1])
endfunction
