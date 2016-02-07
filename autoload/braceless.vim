" I had it in my head that blocks needed to stop when they hit another pattern
" match. They just need to stop at lower-indented lines.  I could hard-code
" the stop pattern, but I don't want to break the magic spell that's making
" this work.
let s:pattern_python = '\%(if\|def\|for\|try\|elif\|else\|with\|class\|while\|except\|finally\)\_.\{-}:'

let s:pattern_coffee = '\%(\zs\%(do\|if\|for\|try\|else\|when\|with\|catch\|class\|while\|switch\|finally\).\+\)\|'
                      \.'\S\&.\+\%(\zs='
                      \.'\|=\s*\zs\%((.*)\)\{,1}\s*[-=]>'
                      \.'\)\s*\_$'

" Gets the byte index of a buffer position
function! s:pos2byte(pos)
  let p = getpos(a:pos)
  return line2byte(p[1]) + p[2]
endfunction


" Similar to prevnonblank() but tests non-empty whitespace lines
function! s:prevnonempty(line)
  let c_line = a:line
  while c_line > 0
    if getline(c_line) !~ '^\s*$'
      return c_line
    endif
    let c_line -= 1
  endwhile
  return 0
endfunction


" Similar to nextnonblank() but tests non-empty whitespace lines
function! s:nextnonempty(line)
  let c_line = a:line
  let end = line('$')
  while c_line <= end
    if getline(c_line) !~ '^\s*$'
      return c_line
    endif
    let c_line += 1
  endwhile
  return 0
endfunction


" Tests if there is selected text
function! s:is_selected()
  let pos = s:pos2byte('.')
  let m_start = s:pos2byte("'<")
  let m_end = s:pos2byte("'>")

  " " echomsg 'Current Position:' pos 'Mark Start:' m_start 'Mark End:' m_end
  return m_start != -1 && m_end != -1 && pos == m_start && pos != m_end
endfunction


" Gets the indent level of a line and modifies it with a indent level delta.
function! s:get_indent(expr, delta)
  let i_c = ' '
  let i_n = indent(a:expr)
  if !&expandtab
    let i_c = '\t'
    let i_n = (i_n / &ts) + a:delta
  else
    let i_n += &sw * a:delta
  endif
  return [i_c, max([0, i_n])]
endfunction


" Get the indented block by finding the first line that matches a pattern that
" looks for a lower indent level.
function! s:get_block_end(start, pattern)
  let end = line('$')
  let start = min([end, a:start + 1])
  let lastline = start

  while start > 0 && start <= end
    if getline(start) =~ a:pattern
      let lastline = prevnonblank(start - 1)
      break
    endif
    let start = s:nextnonempty(start + 1)
  endwhile

  return lastline
endfunction


" Build a pattern that is suitable for the current line and indent level
function! s:build_pattern(line, base, motion, selected)
  let pat = '^\s*'.a:base
  let flag = 'bc'
  let text = getline(a:line)

  if a:selected
    let i_d = 0
    let line = a:line
    if a:motion ==# 'i'
      " Moving inward, include current line
      let flag = 'c'
      let i_d = 1
    else
      " Moving outward, don't include current line
      let flag = 'b'
    endif
    let [i_c, i_n] = s:get_indent(line, i_d - 1)
    let pat = '^'.i_c.'\{,'.i_n.'}'
  elseif text =~ '^\s*$' || text !~ pat
    let [i_c, i_n] = s:get_indent(a:line, -1)
    let pat = '^'.i_c.'\{-,'.i_n.'}'
  else
    " Reset
    let pat = '^\s*'
  endif

  if a:base !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= a:base

  return [pat, flag]
endfunction


" Get the line with the nicest looking indent level
function! s:best_indent(line)
  let p_line = s:prevnonempty(a:line)
  let n_line = s:nextnonempty(a:line)

  " Make sure there's at least something to find
  if p_line == 0
    return 0
  endif

  let p_indent = indent(p_line)
  let n_indent = indent(n_line)

  " If the current line is all whitespace, use one of the surrounding
  " non-empty line's indent level that you may expect to be the selected
  " block.
  if getline(a:line) =~ '^\s*$'
    if p_indent > n_indent
      return n_line
    endif

    return p_line
  endif

  return a:line
endfunction


" Select an indent block using ~magic~
function! braceless#select_block(pattern, stop_pattern, motion, keymode, vmode, op, select)
  let has_selection = 0
  if a:op == ''
    let has_selection = s:is_selected()
  endif

  let c_pos = getpos('.')[1:2]
  let c_line = s:best_indent(line('.'))
  if c_line == 0
    return 0
  endif
  " echomsg 'Start line:' c_line

  " echomsg 'Has Selection:' has_selection
  let [pat, flag] = s:build_pattern(c_line, a:pattern, a:motion, has_selection)
  " echomsg 'Search Pattern:' pat
  " echomsg 'Search Flags:' flag

  let head = searchpos(pat, flag.'W')
  let tail = searchpos(pat, 'nceW')

  let tbyte = line2byte(tail[0]) + tail[1]
  let hbyte = line2byte(head[0]) + head[1]
  " echomsg 'head byte:' hbyte 'tail byte:' tbyte

  if (hbyte == 0 && tbyte == 0) || hbyte == -1 || tbyte == -1
    if a:keymode ==# 'v'
      normal! gV
    else
      call cursor(c_pos[0], c_pos[1])
    endif
    return
  endif

  " Finally begin the block search
  let head = searchpos(pat, 'cbW')
  " echomsg 'Matched Line:' getline(head[0])

  if a:motion ==# 'i'
    let [i_c, i_n] = s:get_indent(head[0], 1)
    call cursor(tail[0] + 1, i_n + 1)
  endif

  if a:keymode == 'v' || a:op != ''
    exec 'normal!' a:vmode
  endif

  let [i_c, i_n] = s:get_indent(head[0], 0)
  let pat = '^'.i_c.'\{,'.i_n.'}'.a:stop_pattern
  " echomsg 'Stop Pattern:' pat
  let lastline = s:get_block_end(line('.'), pat)
  let end = col([lastline, '$'])
  " echomsg 'Last Line' lastline

  if a:select == 1
    call cursor(lastline, end - 1)
  else
    call cursor(c_pos[0], c_pos[1])
  endif

  return [head, tail, lastline]
endfunction


" Gets a pattern.  If g:braceless#start#<filetype> does not exist, fallback to
" a built in one, and if that doesn't exist, return an empty string.
function! s:get_pattern()
  let pattern = get(g:, 'braceless#start#'.&ft, get(s:, 'pattern_'.&ft, ''))
  let stop_pattern = get(g:, 'braceless#stop#'.&ft, get(s:, 'pattern_stop_'.&ft, '\S'))
  return [pattern, stop_pattern]
endfunction


" Kinda like black ops, but more exciting.
function! braceless#block_op(motion, keymode, vmode, op)
  let [pattern, stop_pattern] = s:get_pattern()
  if empty(pattern)
    return
  endif
  call braceless#select_block(pattern, stop_pattern, a:motion, a:keymode, a:vmode, a:op, 1)
endfunction


" Jump to an *actual* meaningful block in Python!
function! braceless#block_jump(direction)
  let [pattern, stop_pattern] = s:get_pattern()
  if empty(pattern)
    return
  endif

  let flags = ''
  if a:direction == -1
    let flags = 'b'
  endif

  let pat = '^\s*'
  if pattern !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= pattern

  let i = v:count1
  while i > 0
    call searchpos(pat, flags.'e')
    let i -= 1
  endwhile
endfunction
