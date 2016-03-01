" Gets the byte index of a buffer position
function! s:pos2byte(pos)
  let p = getpos(a:pos)
  return line2byte(p[1]) + p[2]
endfunction


" Tests if there is selected text
function! s:is_selected()
  let pos = s:pos2byte('.')
  let m_start = s:pos2byte("'<")
  let m_end = s:pos2byte("'>")

  return m_start != -1 && m_end != -1 && pos == m_start && pos != m_end
endfunction


function! s:indent_scan(delta, flags, stopline)
  let [indent_char, indent_len] = braceless#indent#space(line('.'), a:delta)
  let pat = '\_^'.indent_char.'\{'
  if a:delta
    if a:delta == -1
      let pat .= '-,'
    endif
    let pat .= indent_len
  endif
  let pat .= '}'.braceless#get_pattern().start

  if a:stopline
    let stop = '\%'
    if a:stopline < 0
      let stop .= '>'
    else
      let stop .= '<'
    endif
    let stop .= abs(a:stopline).'l'
    let pat = stop.'\&\%('.pat.'\)'
  endif
  return max([1, min([braceless#scan_head(pat, a:flags)[0], line('$')])])
endfunction


function! s:is_decorator_line(pattern)
  if !empty(a:pattern.decorator)
    let pos = getpos('.')
    let head = braceless#scan_head(a:pattern.decorator, 'bc')[0]
    let tail = braceless#scan_head(a:pattern.decorator, 'ec')[0]
    call setpos('.', pos)
    if head != 0 && pos[1] >= head && pos[1] <= tail
      return 1
    endif
  endif

  return 0
endfunction


function! s:iterate_selection(motion, op)
  let pattern = braceless#get_pattern()

  let pat = '^\s*'.pattern.start
  let sel_start = -1
  let sel_end = -1

  call cursor(prevnonblank(line('.')), 1)
  let c_line = line('.')

  if a:op != ''
    " If this is an operation, always operate based on the current line
    let block = braceless#get_block_lines(c_line, 1)
    if a:motion == 'a'
      let sel_start = block[0]
    else
      let sel_start = block[3] + 1
    endif
    let sel_end = block[1]
  elseif s:has_selection
    let sel_start = prevnonblank(s:vstart)
    let sel_end = s:vend
    let block = braceless#get_block_lines(sel_start, 1)

    if a:motion == 'a'
      " There is a selection and we aren't on the first column, scan up for a
      " parent block.
      call cursor(sel_start, 1)
      " let block = braceless#get_block_lines(sel_start)
      if braceless#scan_head(pat, 'nbc')[0] == sel_start && sel_start > block[0]
        let sel_start = block[0]
        let sel_end = block[1]
      elseif braceless#indent#level(sel_start, 0) > 0
        let sel_start = s:indent_scan(-1, 'b', 0)
        let new_block = braceless#get_block_lines(sel_start, 1)
        let sel_end = new_block[1]
      endif
    elseif a:motion == 'i'
      " There is a selection, scan inward to the closest block
      if sel_start == block[3] + 1 && sel_end == block[1]
        let new_block = braceless#get_block_lines(s:indent_scan(0, 'n', 0), 1)
        if new_block[1] <= block[1]
          let block = new_block
          let sel_start = block[3] + 1
          call cursor(sel_start, 1)
        endif
      elseif sel_start >= block[0] && sel_start <= block[1]
        let sel_start = block[3] + 1
        call cursor(sel_start, 1)
      endif
      let sel_end = block[1]
    endif
  else
    if a:motion == 'i'
      " Just find the closest containing block
      call braceless#scan_head(pat, s:is_decorator_line(pattern) ? 'c' : 'bc')[0]
    elseif a:motion == 'a'
      let block = braceless#get_block_lines(c_line, 1)
      if c_line >= block[0] && c_line <= block[3]
        if c_line < block[2]
          " If the line is above the block head, start there.  Most likely
          " decorators.
          let sel_start = block[0]
        else
          " Otherwise, start at the block head
          let sel_start = block[2]
        endif
      else
        let sel_start = s:indent_scan(-1, s:is_decorator_line(pattern) ? 'c' : 'bc', 0)
      endif
    endif
  endif

  let sel_block = braceless#get_block_lines(line('.'), 1)
  if sel_block[3] == sel_block[1]
    " empty body
    let s:vstart = 0
    let s:vend = 0
    return
  endif

  if sel_start == -1
    if a:motion == 'i'
      let sel_start = sel_block[3] + 1
    else
      let sel_start = sel_block[0]
    endif
  endif

  if sel_end == -1
    let sel_end = max([1, sel_start, sel_block[1]])
  endif

  let s:vstart = sel_start
  let s:vend = sel_end
  let s:has_selection = 1
endfunction


" Used for indenting blocks without a body.  Scan for contiguous lines and
" blocks.  The start should be the empty body head.
function! s:adopt_body(start)
  let min_indent = braceless#indent#level(a:start, 0)
  let next_line = nextnonblank(a:start + 1)
  let found = a:start
  let stop = line('$')
  let pat = '^\s*'.braceless#get_pattern().start
  let saved = winsaveview()

  while next_line != 0 && next_line <= stop
    if braceless#is_string(next_line)
      let found = next_line
      let next_line = nextnonblank(next_line + 1)
      continue
    endif

    let line_indent = braceless#indent#level(next_line, 0)
    if line_indent < min_indent
      break
    endif

    call cursor(next_line, 1)
    let head = braceless#scan_head(pat, 'nc')[0]
    if head != 0 && head == next_line
      if line_indent == min_indent
        if next_line - found > 1
          " Only adopt blocks if they are right next to a line that's being
          " adopted.
          break
        endif
        " Found a block, skip to the end
        let block = braceless#get_block_lines(head, 1)
        let next_line = block[1]
      endif
    elseif next_line - found > 2
      break
    endif

    let found = next_line
    let next_line = nextnonblank(found + 1)
  endwhile

  call winrestview(saved)
  return found
endfunction


function! braceless#motion#select(motion, op)
  " Start with the current selection.  These change in s:iterate_selection()
  let s:vstart = getpos("'<")[1]
  let s:vend = getpos("'>")[1]

  " Indent operations do not need a count.  Select contiguous lines on the
  " same indent level as a block without a body, with no more than 1 line
  " separating them.
  if a:op == '<' || a:op == '>'
    let block = braceless#get_block_lines(line('.'), 1)
    if a:motion == 'i'
      let s:vstart = block[3] + 1
      if block[3] == block[1]
        let s:vend = s:adopt_body(block[3])
      else
        let s:vend = block[1]
      endif
    else
      let s:vstart = block[0]
      let s:vend = block[1]
    endif
  else
    let s:has_selection = s:is_selected()
    let c = v:count1

    while c > 0
      let c -= 1
      call s:iterate_selection(a:motion, a:op)
    endwhile
  endif

  if s:vstart != 0 && s:vend != 0
    execute 'keepjumps normal! '.s:vstart.'G^V'.s:vend.'G$'
  endif
endfunction
