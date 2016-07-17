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
      \   'start': '\<\%(if\|def\|for\|try\|elif\|else\|with\|class\|while\|except\|finally\)\>\_.\{-}:\ze\s*\%(\_$\|#\)',
      \   'decorator': '\_^\s*@\%(\k\|\.\)\+\%((\_.\{-})\)\?\_$',
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


" Get the indented block by finding the first line that matches a pattern that
" looks for a lower indent level.
function! s:get_block_end(start, pattern)
  let end = line('$')
  let start = min([end, a:start])
  let lastline = end

  while start > 0 && start <= end
    if getline(start) =~ a:pattern && !braceless#is_string(start, 1)
      let lastline = braceless#prevnonstring(start - 1)
      break
    endif
    let start = nextnonblank(start + 1)
  endwhile

  return prevnonblank(lastline)
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
function! s:build_pattern(line, pattern, ...)
  let pat = '^\s*'.a:pattern.start
  let ignore_empty = 0
  if a:0 != 0
    let ignore_empty = a:1
  endif

  let flag = 'bc'
  let text = getline(a:line)

  let indent_delta = -1
  let indent_line = a:line

  if text !~ '^\s*$'
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

    let head = braceless#scan_head(pat, 'bc')[0]
    let tail = braceless#scan_head(pat, 'ec')[0]
    call setpos('.', pos)

    if head != 0 && indent_line >= head && indent_line <= tail
      " Check if we're on a block head and keep the current indent
      let indent_line = head
      let indent_delta = 0
      call setpos('.', pos2)
    else
      if !empty(a:pattern.decorator)
        call setpos('.', pos2)
        let head = braceless#scan_head(a:pattern.decorator, 'bc')[0]
        let tail = braceless#scan_head(a:pattern.decorator, 'ec')[0]
        call setpos('.', pos)
        if head != 0 && indent_line >= head && indent_line <= tail
          " Check if we're on a decorator line and keep the current indent and
          " set flag to search forward
          let indent_line = head
          let indent_delta = 0
          call setpos('.', pos2)
          let flag = ''
        endif
      endif
    endif
  endif

  let [indent_char, indent_len] = braceless#indent#space(indent_line, indent_delta)

  " Even though we found the indent level of a block, make sure it has a
  " body.  If it doesn't, lower the indent level by one.
  if !ignore_empty && braceless#scan_head('^\s*'.a:pattern.start, 'nc')[0] == indent_line
    let nextline = nextnonblank(indent_line + 1)
    let [_, indent_len2] = braceless#indent#space(nextline, indent_delta)
    if indent_len >= indent_len2
      let [_, indent_len] = braceless#indent#space(indent_line, indent_delta - 1)
    endif
  endif

  let pat = '^'.indent_char.'\{-,'.indent_len.'}'

  if a:pattern.start !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= a:pattern.start

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


let s:syn_string = '\%(String\|Heredoc\|DoctestValue\|DocTest\|DocTest2\|'
                 \.'BytesEscape\|BytesContent\|StrFormat\|StrFormatting\)$'
let s:syn_comment = '\%(Comment\|Todo\)$'
let s:syn_skippable = '\%(Comment\|Todo\|String\|Heredoc\|DoctestValue\|DocTest\|'
                    \.'DocTest2\|BytesEscape\|BytesContent\|StrFormat\|StrFormatting\)$'

" s:syn_check({pattern}, {line} [, {col} [, {either} ]])
" Check if the syntax at a position matches with a pattern.
" If {col} is given, check that specific column, otherwise check both sides
" of the line for a match.
" If {either} is given, either side matching will return 1
function! s:syn_check(pattern, line, ...)
  let text = getline(a:line)
  if a:0 && a:1 > 0
    let c1 = a:1
  else
    let c1 = max([1, match(text, '\S\s*$') + 1])
  endif

  let t1 = synIDattr(synID(a:line, c1, 1), 'name') =~? a:pattern
  let t2 = 1
  if !a:0 || a:1 < 1
    let c2 = max([1, match(text, '\S')])
    let t2 = c2 == c1 || synIDattr(synID(a:line, c2, 1), 'name') =~? a:pattern
  endif

  if a:0 > 1
    return t1 || t2
  endif
  return t1 && t2
endfunction


function! braceless#is_string(line, ...)
  return call('s:syn_check', [s:syn_string, a:line] + a:000)
endfunction


function! braceless#is_comment(line, ...)
  return call('s:syn_check', [s:syn_comment, a:line] + a:000)
endfunction


function! braceless#is_skippable(line, ...)
  return call('s:syn_check', [s:syn_skippable, a:line] + a:000)
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

  if getline(a:line) =~ s:docstr.'.*'.s:docstr && braceless#is_string(a:line, -1, 1)
    return [l, l]
  endif

  let bounds = a:0 ? a:1 : [1, line('$')]

  while l >= bounds[0]
    if getline(l) =~ s:docstr && braceless#is_string(nextnonblank(l + 1))
          \ && !braceless#is_string(prevnonblank(l - 1))
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
          \ && !braceless#is_string(nextnonblank(l + 1))
      let doc_tail = l
      break
    elseif !braceless#is_string(l)
      break
    endif
    let l = nextnonblank(l + 1)
  endwhile

  return [doc_head, doc_tail]
endfunction


" Scans for a block head by making sure the cursor doesn't land in a string or
" comment that looks like a block head.  This moves the cursor.
function! braceless#scan_head(pat, flag) abort
  let saved = {}
  if stridx(a:flag, 'n') != -1
    let saved = winsaveview()
  endif

  let cursor_delta = 0
  if stridx(a:flag, 'c') != -1
    " Ensure the cursor moves if searching from the current position.
    if stridx(a:flag, 'b') != -1
      let cursor_delta = -1
    else
      let cursor_delta = 1
    endif
  endif

  let head = searchpos(a:pat, a:flag.'W')
  if head[0] == 0
    return head
  endif

  if stridx(a:flag, 'b') != -1 && head[0] > 1
        \ && getline(prevnonblank(head[0] - 1)) =~ '\\\s*$'
    call cursor(head[0] - 1, 0)
    let head = braceless#scan_head(a:pat, a:flag)
    if !empty(saved)
      call winrestview(saved)
    endif
    return head
  elseif braceless#is_skippable(head[0], head[1])
    " Initial search landed in a string/comment
    let docstring = braceless#docstring(head[0])
    if docstring[0] != 0
      if stridx(a:flag, 'b') != -1
        let c_line = docstring[0] - 1
      else
        let c_line = docstring[1]
      endif

      if c_line < 1 || c_line > line('$')
        if !empty(saved)
          call winrestview(saved)
        endif
        return [0, 0]
      else
        call cursor(c_line, 0)
      endif
      let head = braceless#scan_head(a:pat, a:flag)
      if !empty(saved)
        call winrestview(saved)
      endif
      return head
    endif
  elseif stridx(a:flag, 'e') == -1
    " Only check if we aren't moving to the end of head since it should
    " naturally land outside of collection brackets because of the pattern.
    let col_saved = winsaveview()
    call cursor(head)

    " Only scan up to 5 lines before the head.
    let stopline = max([1, head[0] - 5])
    let col_start = searchpairpos('(\|{\|\[', '', ')\|}\|\]', 'ncbW',
          \ 'braceless#is_skippable(line(''.''), col(''.''))', stopline)

    if col_start[0] != 0 && col_start != head
      " If searchpair() matches, it means that the head is within a pair
      " (even if it's unclosed).
      if cursor_delta
        call cursor(head[0] + cursor_delta, 0)
      endif
      let head = braceless#scan_head(a:pat, a:flag)
      if !empty(saved)
        call winrestview(saved)
      endif
      return head
    endif
    call winrestview(col_saved)
  endif

  let shit_guard = 5
  while shit_guard > 0 && head[0] != 0
    if braceless#is_skippable(head[0], head[1])
      if cursor_delta
        call cursor(head[0] + cursor_delta, 0)
      endif
      let head = braceless#validsearch(a:pat, a:flag.'W')
      let shit_guard -= 1
      continue
    endif
    break
  endwhile

  if !empty(saved)
    call winrestview(saved)
  endif
  return head
endfunction


" Scan for a block tail by making sure it doesn't land a string or comment.
" This does not move the cursor.
function! braceless#scan_tail(pat, head)
  let tail = searchpos(a:pat, 'nceW')
  " To deal with shitty multiline block starts.  This is an issue for Python
  " where function arguments can be interrupted with comments or have default
  " values which may be a string that looks like the end of the block start.
  " Note: This feels dumb.
  if match(a:pat, '\\_\.\\{-}') != -1
    let shit_guard = 0
    let head_byte = line2byte(a:head[0]) + a:head[1]

    let shit_guard = 5
    while shit_guard > 0 && tail[0] != 0
      let shit_guard -= 1

      if braceless#is_skippable(tail[0], tail[1])
        " If the tail ends up a string or comment, replace the \_.\{-} portion
        " of the pattern with one that specifically skips a certain amount of
        " characters from the start of the head.
        let tail_byte = line2byte(tail[0]) + tail[1]
        let tail_tail = '\\_\.\\{-'.(tail_byte - head_byte).',}'
        let tail = braceless#validsearch(substitute(a:pat, '\\_\.\\{-}', tail_tail, ''), 'nceW')
        continue
      endif
      break
    endwhile
  endif

  return tail
endfunction


" Like searchpos() but skip over certain matches.
" Arguments: {pattern}, {flags} [, {stopline} [, {skip} [, {timeout}]]]
" The {skip} argument is different from |searchpair()|.  It must be a function
" string that takes {line} and {column} as arguments.
function! braceless#validsearch(pattern, flags, ...) abort
  let saved = winsaveview()
  let found = [0, 0]
  let last_found = [0, 0]

  if a:0 > 0
    let stopline = a:1
  else
    let stopline = 0
  endif

  if a:0 > 1
    let skipfunc = a:2
  else
    let skipfunc = 'braceless#is_skippable'
  endif

  if a:0 > 2
    let timeout = a:3
  else
    let timeout = 0
  endif

  let c_delta = 0
  if stridx(a:flags, 'b') != -1 && stridx(a:flags, 'c') != -1
    let c_delta = -1
  elseif stridx(a:flags, 'b') == -1 && stridx(a:flags, 'c')
    let c_delta = 1
  endif

  while found == [0, 0]
    let found = searchpos(a:pattern, a:flags.'W', stopline, timeout)
    if found == last_found
      break
    endif
    let last_found = found
    if found[0] != 0 && call(skipfunc, found)
      call cursor(found[0], found[1] + c_delta)
      let found = [0, 0]
      continue
    endif
  endwhile

  if stridx(a:flags, 'n') != -1
    call winrestview(saved)
  endif

  return found
endfunction


" Gets the bounds of a block head at the current cursor position
function! braceless#head_bounds(...) abort
  let pat = a:0 ? a:1 : '^\s*'.braceless#get_pattern().start
  let saved = winsaveview()
  let head = braceless#scan_head(pat, 'b')
  let tail = [0, 0]
  if head[0] != 0
    let tail = braceless#scan_tail(pat, head)
  endif
  call winrestview(saved)
  return [head, tail]
endfunction


let s:collection = ['(\|{\|\[', ')\|}\|\]']
" Gets the bounds of collection symbols
function! braceless#collection_bounds(...) abort
  let flags_extra = ''
  let stopline = 0
  if a:0 >= 1
    let flags_extra = a:1
    if a:0 >= 2
      let stopline = a:2
    endif
  endif
  let col_head = searchpairpos(s:collection[0], '', s:collection[1], 'nbW'.flags_extra,
        \ 'braceless#is_skippable(line(''.''), col(''.''))', stopline)
  if col_head[0] == 0
    return [[0, 0], [0, 0]]
  endif
  let col_tail = searchpairpos(s:collection[0], '', s:collection[1], 'ncW'.flags_extra,
        \ 'braceless#is_skippable(line(''.''), col(''.''))', stopline)
  return [col_head, col_tail]
endfunction


" Get docstring bounds for the cursor position.
function! braceless#docstring_bounds()
  let saved = winsaveview()
  call braceless#validsearch('\%(\_^\|\_.\)'.s:docstr, 'b')
  " If the first line is hit, validsearch() won't return anything, but the
  " cursor moved there.
  let d_head = getpos('.')[1:2]
  if !(d_head[0] == 1 && d_head[1] == 1) && match(getline(d_head[0]), '^'.s:docstr, d_head[1]) == -1
    let d_head[0] += 1
    let d_head[1] = 1
  else
    let d_head[1] += 1
  endif
  let d_tail = braceless#validsearch(s:docstr.'\zs\%(\_.\|\_$\)', 'n')
  call winrestview(saved)

  return [d_head, d_tail]
endfunction


" Select an indent block using ~magic~
function! braceless#select_block(pattern, ...)
  let ignore_empty = 0
  if a:0 != 0
    let ignore_empty = a:1
  endif

  let saved_view = winsaveview()
  let c_line = s:best_indent(line('.'))
  if c_line == 0
    return [0, 0, 0, 0]
  endif

  let [pat, flag] = s:build_pattern(c_line, a:pattern, ignore_empty)

  let head = braceless#scan_head(pat, flag)
  let tail = braceless#scan_tail(pat, head)

  if head[0] == 0 || tail[0] == 0
    call winrestview(saved_view)
    return [0, 0, head[0], tail[0]]
  endif

  " Finally begin the block search
  let head = searchpos(pat, 'cbW')

  let [indent_char, indent_len] = braceless#indent#space(head[0], 0)
  let pat = '^'.indent_char.'\{,'.indent_len.'}'.a:pattern.stop

  let block_start = head[0]
  let body_start = nextnonblank(tail[0] + 1)
  let block_end = s:get_block_end(body_start, pat)

  if !empty(a:pattern.decorator)
    while 1
      let decorator_tail = search(a:pattern.decorator, 'beW')
      if decorator_tail != 0 && block_start - decorator_tail == 1
        let block_start = search(a:pattern.decorator, 'bW')
        continue
      endif
      break
    endwhile
  endif

  call winrestview(saved_view)

  return [block_start, block_end, head[0], tail[0]]
endfunction


" Try to get a variable from the buffer scope, then global.  Optional second
" argument is the default value.  Return 0 if there's no default.
function! braceless#get_var(name, ...)
  return get(b:, a:name, get(g:, a:name, a:0 ? a:1 : 0))
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
          \   'fold': get(pat, 'fold', get(def, 'fold', start_pat)),
          \   'easymotion': get(pat, 'easymotion', get(def, 'easymotion', start_pat)),
          \   'decorator': get(pat, 'decorator', get(def, 'decorator', '')),
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
  let include_whitespace = 0

  if a:0 > 0
    let ignore_empty = a:1
  endif

  if a:0 > 1
    let include_whitespace = a:2
  endif
  call cursor(a:line, col([a:line, '$']))
  let block = braceless#select_block(pattern, ignore_empty)
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

  if include_whitespace && block[1] < line('$')
    let block[1] = nextnonblank(block[1] + 1) - 1
  endif

  return block
endfunction


function! braceless#get_parent_block_lines(...)
  let saved = winsaveview()
  let block = call('braceless#get_block_lines', a:000)
  let [indent_char, indent_len] = braceless#indent#space(block[2], -1)
  call cursor(block[2], 0)
  let sub = search('^'.indent_char.'\{-,'.indent_len.'}\S', 'nbW')
  let parent = call('braceless#get_block_lines', [sub] + a:000[1:])
  call winrestview(saved)
  return [parent, block]
endfunction


let &cpo = s:cpo_save
unlet s:cpo_save
