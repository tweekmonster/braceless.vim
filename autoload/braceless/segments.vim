" If you're reading this and feel like you can simplify it, that would be
" fantastic.

" Find a block that is the border above the current cursor position.
function! s:find_top_block(pattern) abort
  let level = braceless#indent#level(line('.'), 0)
  let head = -1
  while 1
    let head = braceless#scan_head(a:pattern, 'cb')[0]
    if head == 0
      break
    endif

    if braceless#indent#level(line('.'), 0) <= level
      return braceless#get_block_lines(line('.'), 1, 1)
    endif
    if head == 1
      break
    endif
    call cursor(head - 1, 0)
  endwhile

  return [0, 0, 0, 0]
endfunction


" Get the segment for the line.  If on a block head or blank line, return [0, 0]
function! s:get_segment(line)
  if getline(a:line) =~ '^\s*$'
    return [0, 0]
  endif
  let pattern = '^\s*'.braceless#get_pattern().start

  let saved = winsaveview()
  let pos = [a:line, col(a:line)]

  " Upper boundary
  call cursor(a:line, 1)
  let top_block = s:find_top_block(pattern)
  let top = top_block[0]
  call cursor(a:line, 1)

  " Lower boundary
  let bottom = braceless#scan_head(pattern, 'n')[0]

  if bottom != 0
    let bottom_block = braceless#get_block_lines(bottom, 1, 1)
  else
    let bottom_block = [0, 0, 0, 0]
  endif

  call winrestview(saved)

  let nb_top = nextnonblank(top + 1)
  let nb_bottom = prevnonblank(bottom - 1)

  " The idea here is that the current line is *never* on a block head.  If it
  " is, simply return [0, 0] and let the caller figure out what to do with
  " that.
  if (top != 0 && pos[0] >= top_block[0] && pos[0] <= top_block[3])
        \ || (top != 0 && bottom != 0 && (bottom_block[0] - top_block[3] <= 1 || nb_bottom < nb_top))
    return [0, 0]
  endif

  " Banged my head on the desk over this.  The significant parent is the
  " current line's parent.
  let [parent, _] = braceless#get_parent_block_lines(pos[0], 1, 1)

  " Periods and commas in the diagrams below denote the different segments.
  " All blocks include the whitespace below it to simplify the borders.
  if top == 0 && bottom == 0
    " No block before or after
    " print('top_block')...... <-- Here
    " ........................ <-- Here
    " print('bottom_block')... <-- Here
    let top = 1
    let bottom = line('$')
  elseif top == 0
    " No block before
    " print('top_block')...
    " ..................... <-- Here
    " def bottom_block():
    " ,,,,pass,,,,,,,,,,,,,
    let top = 1
    let bottom = bottom_block[0] - 1
  elseif bottom == 0
    " No block below
    " def top_block():
    " ....pass................
    " ........................ <-- Here
    " print('bottom_block'),,,
    if pos[0] <= parent[1]
      if pos[0] > top_block[1]
        let top = top_block[1] + 1
      else
        let top = top_block[3] + 1
      endif
      let bottom = parent[1]
    elseif pos[0] <= top_block[1]
      let top = top_block[3] + 1
      let bottom = top_block[1]
    else
      " Below the top block
      let top = top_block[1] + 1
      let bottom = line('$')
    endif
  elseif pos[0] > top_block[1] && pos[0] < bottom_block[0]
    " Between blocks
    " def top_block():
    " ....pass...........
    " ................... <-- Here
    " def b():
    " ,,,,pass,,,,,,,,,,,
    " ,,,,,,,,,,,,,,,,,,,
    if pos[0] > parent[1] && pos[0] > top_block[1]
      let top = parent[1] + 1
    else
      let top = top_block[1] + 1
    endif

    if pos[0] <= parent[1] && parent[1] < bottom_block[0]
      " def parent():
      "     def top_block():
      " ........pass........
      " ,,,,pass,,,,,,,,,,,, <-- Here
      " ,,,,,,,,,,,,,,,,,,,, <-- Here
      " def bottom_block():
      let bottom = parent[1]
    elseif pos[0] <= top_block[1]
      let bottom = top_block[1] - 1
    else
      let bottom = bottom_block[0] - 1
    endif
  elseif pos[0] > top_block[3] && pos[0] < bottom_block[0]
    " Between top block head and bottom block head
    " def top_block():
    " ....pass........... <-- Here
    " ................... <-- Here
    "     def b():
    " ,,,,,,,,pass,,,,,,,
    " ,,,,,,,,,,,,,,,,,,,
    let top = top_block[3] + 1
    " Check if top block is within a parent block whose bottom is before the
    " bottom block
    if pos[0] <= parent[1] && parent[1] < bottom_block[0]
      " def parent():
      "     def top_block():
      " ........pass........ <-- Here
      " ,,,,pass,,,,,,,,,,,,
      " ,,,,,,,,,,,,,,,,,,,,
      " def bottom_block():
      if pos[0] <= top_block[1]
        let bottom = top_block[1]
      endif
    elseif bottom_block[0] - top_block[1] > 1
      let bottom = top_block[1] + 1
    else
      let bottom = bottom_block[0] - 1
    endif
  endif

  return [nextnonblank(top), prevnonblank(bottom)]
endfunction


" Like nextnonblank(), but also skips block heads.
function! s:nextnonblock(line) abort
  let pattern = '^\s*'.braceless#get_pattern().start
  let saved = winsaveview()
  let next_line = nextnonblank(a:line)

  call cursor(next_line, col([next_line, '$']))

  let head = braceless#scan_head(pattern, 'bc')
  let tail = braceless#scan_tail(pattern, head)

  while next_line >= head[0] && next_line <= tail[0]
    let next_line = nextnonblank(tail[0] + 1)

    if next_line == 0
      break
    endif

    call cursor(next_line, 1)

    let head = braceless#scan_head(pattern, 'c')
    let tail = braceless#scan_tail(pattern, head)
  endwhile

  call winrestview(saved)
  return next_line
endfunction


" Like prevnonblank(), but also skips block heads.
function! s:prevnonblock(line) abort
  let pattern = '^\s*'.braceless#get_pattern().start
  let saved = winsaveview()
  let next_line = prevnonblank(a:line)

  call cursor(next_line, col([next_line, '$']))

  let head = braceless#scan_head(pattern, 'b')
  let tail = braceless#scan_tail(pattern, head)

  while next_line >= head[0] && next_line <= tail[0]
    let next_line = prevnonblank(head[0] - 1)

    if next_line == 0
      break
    endif

    let head = braceless#scan_head(pattern, 'b')
    let tail = braceless#scan_tail(pattern, head)
  endwhile

  call winrestview(saved)
  return next_line
endfunction


" Get the current segment.  Accepts a second argument that sets the direction
" affinity.
function! braceless#segments#current(line, ...) abort
  let saved = winsaveview()
  let direction = a:0 ? a:1 : 1

  if direction == 1
    let next_line = nextnonblank(a:line)
    if next_line == 0
      let next_line = s:nextnonblock(a:line)
      if next_line == 0
        let next_line = s:prevnonblock(a:line)
      endif
    endif
  else
    let next_line = prevnonblank(a:line)
    if next_line == 0
      let next_line = s:prevnonblock(a:line)
      if next_line == 0
        let next_line = s:nextnonblock(a:line)
      endif
    endif
  endif

  let last_line = line('$')
  let segment = s:get_segment(next_line)
  if segment == [0, 0]
    if direction == 1 && next_line == last_line
      let segment = s:get_segment(s:prevnonblock(next_line))
    elseif direction == 1
      let segment = s:get_segment(s:nextnonblock(next_line))
    else
      let segment = s:get_segment(s:prevnonblock(next_line))
    endif
  endif

  call winrestview(saved)
  return segment
endfunction


" Gets the segment after the current segment.
function! braceless#segments#next(line) abort
  let saved = winsaveview()
  let next_line = s:prevnonblock(a:line)
  let cur_segment = s:get_segment(next_line)
  let last_line = line('$')

  if cur_segment[1] == last_line
    call winrestview(saved)
    return cur_segment
  endif

  let next_line = s:nextnonblock(cur_segment[1] + 1)
  let segment = s:get_segment(next_line)

  while segment == [0, 0] && segment[1] != last_line
    let next_line = s:nextnonblock(next_line + 1)
    let segment = s:get_segment(next_line)
  endwhile

  if segment[0] < cur_segment[0]
    let segment = cur_segment
  endif

  call winrestview(saved)
  return segment
endfunction


" Gets the segment before the current segment.
function! braceless#segments#previous(line) abort
  let saved = winsaveview()
  let next_line = s:nextnonblock(a:line)

  let cur_segment = s:get_segment(next_line)
  if cur_segment[0] == 1
    call winrestview(saved)
    return cur_segment
  endif
  let next_line = s:prevnonblock(cur_segment[0] - 1)
  let segment = s:get_segment(next_line)
  if segment[0] > cur_segment[0] || segment[1] == 0
    let segment = cur_segment
  endif

  call winrestview(saved)
  return segment
endfunction


" Gets the segments that are visible in the buffer
function! braceless#segments#visible() abort
  let line_start = line('w0')
  let line_end = line('w$')

  let segments = []
  let segment = braceless#segments#current(line_start)

  while segment != [0, 0]
    if segment[0] > line_end
      break
    endif
    call add(segments, segment)
    let next_segment = braceless#segments#next(segment[1])
    if next_segment == segment
      break
    endif
    let segment = next_segment
  endwhile

  return segments
endfunction


" Move by a segment.  A segment is content either within a block, or between
" blocks.  It should never land on a block head.
function! braceless#segments#move(direction, top, vmode, op) abort
  " Not v:count1 since we're doing a preliminary positioning
  let c = v:count

  if a:vmode ==? 'v'
    normal! gv
  endif

  let saved = winsaveview()
  let pos = getpos('.')[1:2]

  " Get the current position's segment first
  let segment = braceless#segments#current(pos[0], a:direction)

  let segment_head = indent(segment[0]) + 1
  let segment_tail = col([segment[1], '$']) - 1

  " Position within the current segment only if it make sense for the desired
  " direction.
  if a:top && a:direction == -1 && (pos[0] > segment[0] || pos[1] > segment_head)
    call cursor(segment[0], segment_head)
  elseif !a:top && a:direction == 1 && (pos[0] < segment[1] || pos[1] < segment_tail)
    call cursor(segment[1], segment_tail)
  elseif pos[0] < segment[0] || pos[0] > segment[1]
    " Cursor is outside of the current segment.  Set the position in the
    " current segment to avoid making things more complicated below.
    if a:top
      call cursor(segment[0], segment_head)
    else
      call cursor(segment[1], segment_tail)
    endif
  endif

  let dest = getpos('.')[1:2]

  if segment[0] >= 1 && segment[1] <= line('$')
    if pos != dest
      " The cursor moved within the current segment
      let c -= 1
    elseif c < 1
      " The cursor didn't move.  Add to the operation count to skip the
      " current segment.
      let c += 1
    endif

    let prev_segment = segment

    while c > 0
      let c -= 1
      if a:direction == -1
        let segment = braceless#segments#previous(segment[0])
      else
        let segment = braceless#segments#next(segment[1])
      endif

      if segment == [0, 0] || segment == prev_segment
        break
      endif

      let prev_segment = segment
    endwhile

    if a:top
      call cursor(segment[0], indent(segment[0]) + 1)
    else
      call cursor(segment[1], col([segment[1], '$']) - 1)
    endif
    let dest = getpos('.')[1:2]
  endif

  call winrestview(saved)

  if dest[0] != 0
    execute 'normal! '.dest[0].'G'.dest[1].'|'
  endif
endfunction
