" I had it in my head that blocks needed to stop when they hit another pattern
" match. They just need to stop at lower-indented lines.  I could hard-code
" the stop pattern, but I don't want to break the magic spell that's making
" this work.
let s:cpo_save = &cpo
set cpo&vim

" The cache of found patterns
let s:pattern_cache = {}


" Default patterns
let s:pattern_default = {}
let s:pattern_default.python = {
      \   'start': '\%(if\|def\|for\|try\|elif\|else\|with\|class\|while\|except\|finally\)\_.\{-}:',
      \   'end': '\S',
      \}
let s:pattern_default.coffee = {
      \   'start': '\%('
      \             .'\%(\zs\%(do\|if\|for\|try\|else\|when\|with\|catch\|class\|while\|switch\|finally\).*\)\|'
      \             .'\S\&.\+\%('
      \               .'\zs(.*)\s*[-=]>'
      \               .'\|\((.*)\s*\)\@<!\zs[-=]>'
      \               .'\|\zs=\_$'
      \           .'\)\).*',
      \   'end': '\S',
      \}

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
      let lastline = braceless#prevnonstring(start - 1)
      break
    endif
    let start = nextnonblank(start + 1)
  endwhile

  return lastline
endfunction


" Special case block.  Finds a line that followed by a blank line.
function! s:get_block_until_blank(start)
  let end = line('$')
  let start = min([end, a:start])
  let lastline = end

  while start > 0 && start <= end
    if getline(start + 1) =~ '^$' && !braceless#is_string(start)
      let lastline = braceless#prevnonstring(start)
      break
    endif
    let start = nextnonblank(start + 1)
  endwhile

  return lastline
endfunction


" Build a pattern that is suitable for the current line and indent level
function! s:build_pattern(line, base, motion, selected, ...)
  let pat = '^\s*'.a:base
  let flag = 'bc'
  let text = getline(a:line)
  let ignore_empty = 0
  if a:0 != 0
    let ignore_empty = a:1
  endif

  " Get a line with a lower indent level than the current line to figure out
  " whether or not this line can actually determine the parent block.
  let [indent_char, indent_len] = braceless#indent#space(a:line, -1)
  let prev_unindent = search('^'.indent_char.'\{-,'.indent_len.'}\S', 'nbW')
  if indent_len != 0 && prev_unindent != 0 && getline(prev_unindent) !~ '^\s*'.a:base
    " The current line is indented under a non-block line.  This might mean
    " line continuations, lists, or something.  Try again.
    call cursor(prev_unindent, col('.'))

    " Though this is recursive, it'll stop before it hits the first column.
    " Performance is a consideration, but if unexpected indentation is that
    " deep, there are more pressing matters that the user is facing.
    return s:build_pattern(prev_unindent, a:base, a:motion, a:selected, ignore_empty)
  endif

  if a:selected
    let indent_delta = 0
    if a:motion ==# 'i'
      " Moving inward, include current line
      let flag = 'c'
      let indent_delta = 1
    else
      " Moving outward, don't include current line
      let flag = 'b'
    endif
    let [indent_char, indent_len] = braceless#indent#space(a:line, indent_delta - 1)
    let pat = '^'.indent_char.'\{,'.indent_len.'}'
  else
    let indent_delta = 0
    let indent_line = a:line
    if text =~ '^\s*$'
      let indent_delta = -1
    else
      " motions can get screwed up if initiated from within a docstring
      " that's under indented.
      if braceless#is_string(a:line)
        let docstring = braceless#docstring(a:line)
        if docstring[0] != 0
          let indent_line = docstring[0]
        endif
      endif

      " Try matching a multi-line block start
      " The window state should be saved before this, so no need to restore
      " the curswant
      let pos = getpos('.')
      call cursor(indent_line, col([indent_line, '$']))
      let pos2 = getpos('.')
      let head = searchpos(pat, 'cbW')
      let tail = searchpos(pat, 'ceW')
      call setpos('.', pos)
      if tail[0] == pos2[1] || head[0] == pos2[1]
        let indent_line = head[0]
        let indent_delta = 0
        " Move to the head line
        call setpos('.', pos2)
      else
        let indent_delta = -1
      endif
    endif

    let [indent_char, indent_len] = braceless#indent#space(indent_line, indent_delta)

    " Even though we found the indent level of a block, make sure it has a
    " body.  If it doesn't, lower the indent level by one.
    if !ignore_empty && getline(indent_line) =~ '^\s*'.a:base
      let nextline = nextnonblank(indent_line + 1)
      let [_, indent_len2] = braceless#indent#space(nextline, indent_delta)
      if indent_len >= indent_len2
        let [_, indent_len] = braceless#indent#space(indent_line, indent_delta - 1)
      endif
    endif

    let pat = '^'.indent_char.'\{-,'.indent_len.'}'
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


let s:syn_string = '\(String\|Heredoc\)$'

function! braceless#is_string(line, ...)
  return synIDattr(synID(a:line, a:0 ? a:1 : col([a:line, '$']) - 1, 1), 'name') =~ s:syn_string
        \ && (a:0 || synIDattr(synID(a:line, 1, 1), 'name') =~ s:syn_string)
endfunction


function! braceless#prevnonstring(line)
  let l = prevnonblank(a:line)
  while l > 0
    if !braceless#is_string(l)
      return l
    endif
    let l = prevnonblank(l - 1)
  endwhile

  return l
endfunction


let s:docstr = '\%("""\|''''''\)'
" Returns the start and end lines for docstrings
" Couldn't get this to work reliably using searches.
function! braceless#docstring(line, ...)
  let l = nextnonblank(a:line)
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

  let l = prevnonblank(a:line)
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
function! braceless#select_block(pattern, motion, keymode, vmode, op, select, ...)
  let has_selection = 0
  let ignore_empty = 0
  if a:0 != 0
    let ignore_empty = a:1
  endif

  if a:op == ''
    let has_selection = s:is_selected()
  elseif a:op == '<' || a:op == '>'
    let ignore_empty = 1
  endif

  let saved_view = winsaveview()
  let c_line = s:best_indent(line('.'))
  if c_line == 0
    return 0
  endif

  let [pat, flag] = s:build_pattern(c_line, a:pattern.start, a:motion, has_selection, ignore_empty)

  let head = searchpos(pat, flag.'W')
  let tail = searchpos(pat, 'nceW')

  if head[0] == 0 || tail[0] == 0
    if a:keymode ==# 'v'
      normal! gV
    else
      call winrestview(saved_view)
    endif
    return [c_line, c_line, head[0], tail[0]]
  endif

  " Finally begin the block search
  let head = searchpos(pat, 'cbW')

  let [indent_char, indent_len] = braceless#indent#space(head[0], 0)
  let pat = '^'.indent_char.'\{,'.indent_len.'}'.a:pattern.stop

  let startline = nextnonblank(tail[0] + 1)
  let lastline = s:get_block_end(startline, pat)

  if a:motion ==# 'i'
    if lastline < startline
      if a:op == '<' || a:op == '>'
        let lastline = s:get_block_until_blank(startline)
        let [indent_char, indent_len] = braceless#indent#space(head[0], 1)
        call cursor(tail[0] + 1, indent_len + 1)
      else
        call cursor(tail[0], 0)
      endif
    else
      let [indent_char, indent_len] = braceless#indent#space(head[0], 1)
      call cursor(tail[0] + 1, indent_len + 1)
    endif
  endif

  " TODO: Revisit this and make sure none of this is superfluous or just bad
  if a:op != '' || (!empty(a:vmode) && a:select == 1 && a:keymode == 'v')
    normal! V
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


" Gets a pattern.  If g:braceless#pattern#<filetype> does not exist, fallback to
" a built in one, and if that doesn't exist, use basic matching
function! braceless#get_pattern(...)
  let lang = &ft
  if a:0 > 0 && type(a:1) == 1
    let lang = a:1
  endif

  if !has_key(s:pattern_cache, lang)
    let pat = get(g:, 'braceless#pattern#'.lang, {})
    let def = get(s:pattern_default, lang, {})
    let start_pat = get(pat, 'start', get(def, 'start', '\S.*'))
    let stop_pat = get(pat, 'stop', get(def, 'stop', '\S'))
    let s:pattern_cache[lang] = {
          \   'start': start_pat,
          \   'stop': stop_pat,
          \   'jump': get(pat, 'jump', get(def, 'jump', start_pat)),
          \   'easymotion': get(pat, 'easymotion', get(def, 'easymotion', start_pat)),
          \ }
  endif
  return get(s:pattern_cache, lang)
endfunction


" Define a pattern directly with reckless abandon.  If a:patterns is not a
" dict, the a:filetype item will be removed from the cache.
function! braceless#define_pattern(filetype, patterns)
  if type(patterns) != 4 && has_key(s:pattern_cache, a:filetype)
    unlet s:pattern_cache[a:filetype]
    return
  endif

  let s:pattern_cache[a:filetype] = a:patterns
endfunction


" Gets the lines involved in a block without selecting it
function! braceless#get_block_lines(line, ...)
  let pattern = braceless#get_pattern()
  let saved = winsaveview()
  let ignore_empty = 0
  if a:0 != 0
    let ignore_empty = a:1
  endif
  call cursor(a:line, col([a:line, '$']))
  let block = braceless#select_block(pattern, 'a', 'n', '', '', 0, ignore_empty)
  call winrestview(saved)
  if type(block) != 3
    return
  endif

  let prev_line = prevnonblank(block[0])
  let next_line = nextnonblank(block[0])
  if indent(next_line) < indent(prev_line)
    let block[0] = prev_line
  else
    let block[0] = next_line
  endif

  return block
endfunction


" Kinda like black ops, but more exciting.
function! braceless#block_op(motion, keymode, vmode, op)
  let pattern = braceless#get_pattern()
  call braceless#select_block(pattern, a:motion, a:keymode, a:vmode, a:op, 1)
endfunction


let &cpo = s:cpo_save
unlet s:cpo_save
