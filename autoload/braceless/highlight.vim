function! s:highlight_line(line1, line2)
  let use_cc = get(b:braceless, 'highlight_cc', 0)
  if !has_key(b:braceless, 'orig_cc')
    let b:braceless.orig_cc = &l:cc
  endif

  if a:line1 < 1
    if use_cc
      let &l:cc = b:braceless.orig_cc
    endif

    call s:mark_column(0, 0, 0)
    return
  endif

  let [_, indent_len] = braceless#indent#space(a:line1, 0)

  if use_cc > 0
    let &l:cc = (b:braceless.orig_cc != '' ? b:braceless.orig_cc.',' : '').(indent_len+1)
    if use_cc == 1
      return
    endif
  endif

  call s:mark_column(a:line1, a:line2, indent_len)
endfunction


function! s:mark_column(line1, line2, column)
  if has_key(b:braceless, 'highlight_column')
    for id in b:braceless.highlight_column
      silent! call matchdelete(id)
    endfor
    unlet b:braceless.highlight_column
    silent! unlet w:braceless_highlight_cache
  endif

  if a:line1 == 0
    return
  endif

  if a:line2 - a:line1 < 1
    return
  endif

  let matches = []

  if exists('*matchaddpos')
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
  else
    " For Vim < 7.4.330
    " Based on profiling, matchaddpos() is faster despite the loop to add
    " multiple positions due to the 8 item limit.
    let first_line = max([1, nextnonblank(a:line1 + 1) - 1])
    let last_line = prevnonblank(a:line2) + 1
    let id = matchadd('BracelessIndent', '\%(\%>'.first_line.'l\&\%<'.last_line.'l\)\&\%'.(a:column+1).'v', 90)
    call add(matches, id)
  endif

  let b:braceless.highlight_column = matches
endfunction


" Enable/disable block highlighting on a per-buffer basis
function! braceless#highlight#enable(b)
  let b:braceless.highlight = a:b
  if a:b
    call braceless#highlight#update(1)

    augroup braceless_highlight
      autocmd! * <buffer>
      autocmd CursorMoved,CursorMovedI,TextChanged,TextChangedI <buffer> call braceless#highlight#update(0)
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
  call braceless#highlight#enable(!get(b:braceless, 'highlight', 0))
endfunction


" Highlight indent block
function! braceless#highlight#update(force)
  if !get(b:braceless, 'highlight', 0)
    return
  endif

  let l = line('.')
  let pattern = braceless#get_pattern()
  let pblock = braceless#scan_head('^\s*'.pattern.start, 'ncb')[0]
  let indent_level = braceless#indent#level(prevnonblank(l), 0)

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
  call s:highlight_line(block[2], block[1])
endfunction
