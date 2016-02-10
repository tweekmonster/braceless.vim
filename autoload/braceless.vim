" I had it in my head that blocks needed to stop when they hit another pattern
" match. They just need to stop at lower-indented lines.  I could hard-code
" the stop pattern, but I don't want to break the magic spell that's making
" this work.
let s:cpo_save = &cpo
set cpo&vim

let s:pattern_python = '\%(if\|def\|for\|try\|elif\|else\|with\|class\|while\|except\|finally\)\_.\{-}:'

let s:pattern_coffee = '\%('
                      \  .'\%(\zs\%(do\|if\|for\|try\|else\|when\|with\|catch\|class\|while\|switch\|finally\).*\)\|'
                      \  .'\S\&.\+\%('
                      \    .'\zs(.*)\s*[-=]>'
                      \    .'\|\((.*)\s*\)\@<!\zs[-=]>'
                      \    .'\|\zs=\_$'
                      \.'\)\).*'

" Coffee Script is tricky as hell to match.  Explanation of above:
" - Start an atom that groups everything, so that searchpos() will match the
"   entire line.
"   - Match block keywords
"   - Start an atom that matches symbols that start a block
"     - Match a splat with arguments to position at the beginning of the
"     arguments
"     - Match a splat without arguments.  Explicitly don't match splat with
"     arguments, since it would technically match.
"     - An equal sign at the end of a line
" - Close the atoms


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

  " echomsg 'Current Position:' pos 'Mark Start:' m_start 'Mark End:' m_end
  return m_start != -1 && m_end != -1 && pos == m_start && pos != m_end
endfunction


" Get the indented block by finding the first line that matches a pattern that
" looks for a lower indent level.
function! s:get_block_end(start, pattern)
  let end = line('$')
  let start = min([end, a:start])
  let lastline = end

  while start > 0 && start <= end
    if getline(start) =~ a:pattern && !braceless#is_string(start)
      let lastline = prevnonblank(start - 1)
      break
    endif
    let start = nextnonblank(start + 1)
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
    let [i_c, i_n] = braceless#indent#space(line, i_d - 1)
    let pat = '^'.i_c.'\{,'.i_n.'}'
  else
    let i_d = 0
    let i_l = a:line
    if text =~ '^\s*$'
      let i_d = -1
    else
      " motions can get screwed up if initiated from within a docstring
      " that's under indented.
      if braceless#is_string(a:line)
        let docstring = braceless#docstring(a:line)
        if docstring[0] != 0
          let i_l = docstring[0]
        endif
      endif

      " Try matching a multi-line block start
      " The window state should be saved before this, so no need to restore
      " the curswant
      let pos = getpos('.')
      call cursor(i_l, col([i_l, '$']))
      let pos2 = getpos('.')
      let head = searchpos(pat, 'cbW')
      let tail = searchpos(pat, 'ceW')
      call setpos('.', pos)
      if tail[0] == pos2[1] || head[0] == pos2[1]
        let i_l = head[0]
        let i_d = 0
        " Move to the head line
        call setpos('.', pos2)
      else
        let i_d = -1
      endif
    endif

    let [i_c, i_n] = braceless#indent#space(i_l, i_d)
    let pat = '^'.i_c.'\{-,'.i_n.'}'
  endif

  if a:base !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= a:base

  return [pat, flag]
endfunction


" Get the line with the nicest looking indent level
function! s:best_indent(line)
  let p_line = prevnonblank(a:line)
  let n_line = nextnonblank(a:line)

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


let s:docstr = '\%("""\|''''''\)'

function! braceless#is_string(line, ...)
  return synIDattr(synID(a:line, a:0 ? a:1 : 1, 1), 'name') =~ '\(Comment\|Todo\|String\|Heredoc\)$'
endfunction


" Returns the start and end lines for docstrings
" Couldn't get this to work reliably using searches.
function! braceless#docstring(line, ...)
  let l = prevnonblank(a:line)
  let doc_head = 0
  let doc_tail = 0

  let bounds = a:0 ? a:1 : [1, line('$')]

  while l >= bounds[0]
    if getline(l) =~ s:docstr && braceless#is_string(nextnonblank(l + 1))
      let doc_head = l
      break
    elseif !braceless#is_string(l)
      break
    endif
    let l = prevnonblank(l - 1)
  endwhile

  if doc_head == 0
    return [0, 0]
  endif

  let l = nextnonblank(a:line)
  while l <= bounds[1]
    if getline(l) =~ s:docstr && braceless#is_string(prevnonblank(l - 1))
      let doc_tail = l
      break
    elseif !braceless#is_string(l)
      break
    endif
    let l = nextnonblank(l + 1)
  endwhile

  return [doc_head, doc_tail]
endfunction

" Select an indent block using ~magic~
function! braceless#select_block(pattern, stop_pattern, motion, keymode, vmode, op, select)
  let has_selection = 0
  if a:op == ''
    let has_selection = s:is_selected()
  endif

  let saved_view = winsaveview()
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
  " echomsg 'Head Byte:' hbyte 'Tail Byte:' tbyte

  if (hbyte == 0 && tbyte == 0) || hbyte == -1 || tbyte == -1
    if a:keymode ==# 'v'
      normal! gV
    else
      call winrestview(saved_view)
    endif
    return [c_line, c_line, head[0], tail[0]]
  endif

  " Finally begin the block search
  let head = searchpos(pat, 'cbW')
  " echomsg 'Matched Line:' getline(head[0])

  let [i_c, i_n] = braceless#indent#space(head[0], 0)
  let pat = '^'.i_c.'\{,'.i_n.'}'.a:stop_pattern
  " echomsg 'Stop Pattern:' pat

  let startline = nextnonblank(tail[0] + 1)
  let lastline = s:get_block_end(startline, pat)

  if a:motion ==# 'i'
    if lastline < startline
      call cursor(tail[0], 0)
    else
      let [i_c, i_n] = braceless#indent#space(head[0], 1)
      call cursor(tail[0] + 1, i_n + 1)
    endif
  endif

  if !empty(a:vmode) && a:select == 1 && (a:keymode == 'v' || a:op != '')
    if a:op ==? 'y'
      normal! V
    else
      exec 'normal!' a:vmode
    endif
  endif

  if lastline < startline
    if a:select == 1
      call cursor(tail[0], tail[1])
    else
      call winrestview(saved_view)
    endif
    return [lastline, lastline, head[0], tail[0]]
  endif

  let end = col([lastline, '$'])
  " echomsg 'Last Line' lastline

  if a:select == 1
    call cursor(lastline, end - 1)
  else
    call winrestview(saved_view)
  endif

  if a:motion ==# 'a'
    let startline = head[0]
  endif

  return [startline, lastline, head[0], tail[0]]
endfunction


" Gets a pattern.  If g:braceless#start#<filetype> does not exist, fallback to
" a built in one, and if that doesn't exist, return an empty string.
function! braceless#get_pattern()
  let pvar = 'pattern_pair_'.&ft
  if !exists('s:'.pvar)
    let pattern = get(g:, 'braceless#start#'.&ft, get(s:, 'pattern_'.&ft, '\S.*'))
    let stop_pattern = get(g:, 'braceless#stop#'.&ft, get(s:, 'pattern_stop_'.&ft, '\S'))
    let s:[pvar] = [pattern, stop_pattern]
  endif
  return get(s:, pvar)
endfunction


" Enable/disable block highlighting on a per-buffer basis
function! braceless#enable_highlight(b)
  let b:braceless_enable_highlight = a:b
  if a:b
    silent call braceless#highlight(1)
  else
    call s:mark_column(0, 0, 0)
  endif
endfunction


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

  let [i_c, i_n] = braceless#indent#space(a:line1, 0)

  if use_cc > 0
    let &cc = s:origcc.','.(i_n+1)
    if use_cc == 1
      return
    endif
  endif

  call s:mark_column(a:line1, a:line2, i_n)
endfunction


function! s:mark_column(line1, line2, column)
  if exists('b:braceless_column')
    for id in b:braceless_column
      silent! call matchdelete(id)
    endfor
    unlet b:braceless_column
  endif

  if a:line1 == 0
    return
  endif

  if a:line2 - a:line1 < 1
    return
  endif

  " echomsg a:line1 '-' a:line2 '-' a:column

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


function! braceless#get_block_lines(line)
  let [pattern, stop_pattern] = braceless#get_pattern()
  if empty(pattern)
    return
  endif

  let saved = winsaveview()
  call cursor(a:line, col([a:line, '$']))
  let il = braceless#select_block(pattern, stop_pattern, 'a', 'n', '', '', 0)
  call winrestview(saved)
  if type(il) != 3
    return
  endif

  let pl = prevnonblank(il[0])
  let nl = nextnonblank(il[0])
  if indent(nl) < indent(pl)
    let il[0] = pl
  else
    let il[0] = nl
  endif

  return il
endfunction


" Highlight indent block
function! braceless#highlight(ignore_prev)
  if !get(b:, 'braceless_enable_highlight', get(g:, 'braceless_enable_highlight', 0))
    return
  endif

  let l = line('.')
  let last_line = get(b:, 'braceless_last_line', 0)

  let b:braceless_last_line = l
  let il = braceless#get_block_lines(line('.'))
  if type(il) != 3
    return
  endif

  if !a:ignore_prev
    let last_range = get(b:, 'braceless_range', [0, 0])
    if il[0] == last_range[0] && il[1] == last_range[1]
      return
    endif
  endif

  let b:braceless_range = il

  call s:highlight_line(il[0], il[1])
endfunction


" Folding
function! braceless#foldexpr(line)
  silent let il = braceless#get_block_lines(a:line)
  if type(il) != 3
    return 0
  endif

  let inner = get(b:, 'braceless_fold_inner', get(g:, 'braceless_fold_inner', 0))
  let i_n = braceless#indent#level(il[2], 1)

  if a:line != il[0] && a:line == il[3]
    return -1
  elseif a:line == il[0]
    return inner ? i_n - 1 : '>'.i_n
  elseif inner && a:line == il[0]+1
    return '>'.i_n
  elseif a:line == il[1]
    return '<'.i_n
  endif
  return i_n
endfunction


function! braceless#enable_folding()
  setlocal foldmethod=expr
  setlocal foldexpr=braceless#foldexpr(v:lnum)
endfunction



" Kinda like black ops, but more exciting.
function! braceless#block_op(motion, keymode, vmode, op)
  let [pattern, stop_pattern] = braceless#get_pattern()
  if empty(pattern)
    return
  endif
  call braceless#select_block(pattern, stop_pattern, a:motion, a:keymode, a:vmode, a:op, 1)
endfunction


" Jump to an *actual* meaningful block in Python!
function! braceless#block_jump(direction, vmode, count)
  let [pattern, stop_pattern] = braceless#get_pattern()
  if empty(pattern)
    return
  endif

  if a:vmode != 'n'
    normal! gv
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

  let i = a:count
  while i > 0
    call searchpos(pat, flags.'e')
    let i -= 1
  endwhile
endfunction


" EasyMotion for indent blocks
function! braceless#easymotion(vmode, direction)
  let [pattern, stop_pattern] = braceless#get_pattern()
  if empty(pattern)
    return
  endif

  let pat = '^\s*'
  if pattern !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= pattern

  if pattern !~ '\\ze'
    let pat .= '\ze'
  endif

  call EasyMotion#User(pat, a:vmode, a:direction, 1)
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
