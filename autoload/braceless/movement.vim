" Jump to an *actual* meaningful block in Python!
function! braceless#movement#block(direction, vmode, by_indent, count)
  let pattern = braceless#get_pattern()

  if a:vmode != 'n'
    normal! gv
  endif

  let flags = ''
  if a:direction == -1
    let flags = 'b'
  endif

  let pat = '^'
  if a:by_indent
    let block = braceless#get_block_lines(line('.'))
    let [indent_char, indent_len] = braceless#indent#space(block[2], a:direction)
    let pat .= indent_char.'\{'.indent_len.'}'
  else
    let pat .= '\s*'
  endif

  if pattern.jump !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= pattern.jump

  let i = a:count
  while i > 0
    call braceless#scan_head(pat, flags.'e')
    let i -= 1
  endwhile
endfunction



" Note: I think everything below needs some refactoring.

" Positions the cursor after movement in function below
function! s:position_inner_block(pat, top)
  if a:top
    let top = braceless#scan_head(a:pat, 'nceb')[0]
    if top == 0
      let top = 1
    else
      let block = braceless#get_block_lines(top + 1)
      if block[1] < line('.')
        let top = nextnonblank(block[1] + 1)
      else
        let top = nextnonblank(top + 1)
      endif
    endif
    let [_, indent_len] = braceless#indent#space(top, 0)
    call cursor(top, indent_len + 1)
  else
    let bottom = braceless#scan_head(a:pat, 'nc')[0]
    if bottom == 0
      let bottom = prevnonblank(line('.'))
    else
      let block = braceless#get_block_lines(line('.'))
      if block[1] < bottom
        let bottom = prevnonblank(block[1])
      else
        let bottom = prevnonblank(bottom - 1)
      endif
    endif
    call cursor(bottom, col([bottom, '$']) - 1)
  endif
endfunction


" Returns the line of the next block boundary depending on direction.  A block
" boundary is considered anything that's between block heads and block ends,
" and vice versa.
function! s:skip_boundary(pat, direction, start)
  let flags = 'W'
  if a:direction == -1
    let flags .= 'b'
  else
    let flags .= 'e'
  endif
  let pos = getpos('.')[1:2]
  let found = braceless#scan_head(a:pat, flags)[0]

  if found == 0
    if a:direction == -1
      let l = prevnonblank(pos[0] - 1)
      if l == 0
        let l = 1
      endif
    else
      let l = nextnonblank(pos[0] + 1)
      if l == 0
        let l = line('$')
      endif
    endif

    call cursor(pos)
    return l
  endif

  if a:direction == -1
    let block = braceless#get_block_lines(found)
    if block[0] != 0 && block[1] < pos[0]
      let found = prevnonblank(block[1])
    else
      let prev_found = braceless#scan_head(a:pat, flags.'n')[0]
      if abs(found - prev_found) <= 1
        let found = s:skip_boundary(a:pat, a:direction, a:start)
      else
        let found = prevnonblank(found - 1)
      endif
    endif
  else
    let block = braceless#get_block_lines(pos[0])
    let n = nextnonblank(block[1] + 1)
    if n != 0 && n < found
      " Too far beyond the current block
      let found = nextnonblank(n - 1)
    else
      let next_found = braceless#scan_head(a:pat, flags.'n')[0]
      if abs(next_found - found) <= 1
        " Too close to another block head
        let found = s:skip_boundary(a:pat, a:direction, a:start)
      else
        let found = nextnonblank(found + 1)
      endif
    endif
  endif

  call cursor(pos)
  return found
endfunction


function! braceless#movement#inner_block(direction, vmode, inclusive, top)
  if a:vmode == 'v'
    normal! gv
  endif

  let pattern = braceless#get_pattern()
  let pat = '^\s*'
  if pattern.jump !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= pattern.jump

  let c = a:inclusive ? v:count : v:count1
  let pos = getpos('.')[1:2]
  let flag = ''
  let alt_flag = ''
  if a:direction == -1
    let flag = 'b'
    let next_flag = 'nb'
  else
    let flag = 'e'
    let next_flag = 'ne'
  endif

  let c_line = line('.')
  while c > 0
    let c_line = s:skip_boundary(pat, a:direction, c_line)
    if c_line == 0
      break
    endif
    call cursor(c_line, 0)
    let c -= 1
  endwhile

  call s:position_inner_block(pat, a:top)
endfunction
