let s:indent_handler = {}
let s:call_pattern = '\k\+\s*(\zs\_.\{-}\ze)\?'
let s:if_pattern = 'if\s*(\zs\_.\{-}\ze)\?'
let s:stmt_pattern = 'def '.s:call_pattern


" This function exists because the repetition below felt dirty.
" lonely_head_indent is the indent delta for heads that don't have trailing
" text after them.  greedy is a boolean that forces non-lonely heads to take
" the lonely_head_indent level.
function! s:get_block_indent(pattern, line, col_head, col_tail, lonely_head_indent, greedy)
  let head = search(a:pattern, 'bW')
  if head != 0 && a:col_head[0] == head
    let lonely = getline(head) =~ '\%((\|{\|\[\)\s*$'
    if lonely && a:line == a:col_tail[0] && getline(a:line) =~ '^\s*\%()\|}\|\]\)\+\s*'
      return braceless#indent#space(head, 0)[1]
    elseif a:greedy || lonely
      return braceless#indent#space(head, a:lonely_head_indent)[1]
    endif
  endif
  return -1
endfunction


" Handle function arguments, which are seen as collections by Braceless.
" If it looks like function is being called and there are no arguments
" immediately after the opening parenthesis, indentation level is increased by
" 1 or 2, depending on whether or not it's a block line.
"
" If the function is being called, but has text after the opening parenthesis,
" set the indent to match the opening parenthesis position.
"
" https://www.python.org/dev/peps/pep-0008/#indentation
function! s:indent_handler.collection(line, col_head, col_tail)
  let pos = getpos('.')[1:2]
  call cursor(a:line, 0)

  " Special case for if statements using parenthesis to indent
  let i = s:get_block_indent(s:if_pattern, a:line, a:col_head, a:col_tail,
        \ braceless#get_var('braceless_cont_block', 2), 1)
  if i != -1
    return i
  endif

  let i = s:get_block_indent(s:stmt_pattern, a:line, a:col_head, a:col_tail,
        \ braceless#get_var('braceless_cont_block', 2), 0)
  if i != -1
    return i
  endif

  call cursor(pos)

  let lonely_head_indent = braceless#get_var('braceless_cont_call', 0)
  let greedy = 1
  if !lonely_head_indent
    let lonely_head_indent = 1
    let greedy = 0
  endif

  let i = s:get_block_indent(s:call_pattern, a:line, a:col_head, a:col_tail,
        \ lonely_head_indent, greedy)
  if i != -1
    return i
  endif

  call cursor(pos)

  if a:line == a:col_tail[0] && a:col_head[0] != a:col_tail[0]
    let head = getline(a:col_head[0])
    if head !~ '\%((\|{\|\[\)\s*$'
      return a:col_head[1]
    elseif getline(a:col_tail[0]) !~ '^\s*\%()\|}\|\]\),\?\s*'
      return braceless#indent#space(a:col_head[0], 1)[1]
    endif
    return braceless#indent#space(a:col_head[0], 0)[1]
  endif

  throw 'cont'
endfunction


" Scan upward for a parent block matching the name.  `indent_from` is the line
" to take the indent level from.  `start` and `stop` are the bounds for the
" search.  `exact` tells the search to match the indent level exactly.
function! s:scan_parent(name, indent_from, start, stop, exact)
  let [indent_char, indent_len] = braceless#indent#space(a:indent_from, 0)
  let pat = '^'
  if a:stop
    let pat .= '\%>'.a:stop.'l\&'
  endif
  let pat .= '\%('.indent_char
  if a:exact
    let pat .= '\{'.indent_len.'}'
  else
    let pat .= '*'
  endif
  let pat .= '\%('.a:name.'\)\_.\{-}:\ze\s*\%(\_$\|#\)\)'
  let pos = getpos('.')[1:2]
  call cursor(a:start, col([a:start, '$']))
  let found = braceless#scan_head(pat, 'ncbW')[0]
  call cursor(pos)
  return found
endfunction


function! s:get_parent(name, indent_from, start)
  let found = s:scan_parent(a:name, a:indent_from, a:start, 0, 1)
  let saved = winsaveview()
  call cursor(a:start, 1)
  let prevhead = braceless#scan_head(braceless#get_pattern().start, 'nb')
  call winrestview(saved)
  if getline(prevhead[0]) =~ '^\s*'.a:name
    return prevehead[0]
  endif

  if found
    let block = braceless#get_block_lines(found)
    if block[1]
  endif
endfunction

" Indent based on the current block and its expected sibling
function! s:contextual_indent(line, kw)
  let found = -1
  let prev = prevnonblank(a:line - 1)

  if a:kw == 'else'
    let parent = 'if\|try\|for\|elif\|while\|except'
  elseif a:kw == 'elif'
    let parent = 'if'
  elseif a:kw == 'except'
    let parent = 'try'
  elseif a:kw == 'finally'
    let parent = 'try'
  else
    " Let the default block indentation take over
    throw 'cont'
  endif

  let found = s:scan_parent(parent, a:line, a:line, 0, 0)
  if found == 0
    " Even though we had a reason to check, we didn't find a match
    throw 'cont'
  endif

  if a:kw == 'else' || a:kw == 'elif' || a:kw == 'finally'
    " `scan` is what should *not* be on the same indent level as the parent
    if a:kw == 'elif'
      let scan = 'else'
    else
      " else and finally should be unique in their block set
      let scan = a:kw
    endif

    let found_exact = s:scan_parent(parent, a:line, a:line, 0, 1)
    if found_exact
      let exact_block = braceless#get_block_lines(found_exact, 1)
      if exact_block[1] == prev
        " Found a parent that's on the same indent and borders this block
        let found = found_exact
      endif
    endif

    let other = s:scan_parent(scan, found, prev, found, 1)
    if other != 0 && indent(other) == 0
      " There is no competing block
      throw 'cont'
    endif

    " There is a competing block.  Figure out where the current block fits.
    let last_found = found
    let seen = []
    while other != 0 && indent(found) == indent(other)
      " Keep searching if a competing block is matched with the desired parent
      " Note: Should there be a limit to this?  Should I care about deeply
      " nested blocks?
      let found = s:scan_parent(parent, found, found - 1, 0, 0)
      let other = s:scan_parent(scan, found, prev, found, 1)

      if index(seen, other) != -1
        " Guard against infinite loop
        break
      endif

      call add(seen, other)
    endwhile
  endif

  return braceless#indent#space(found, 0)[1]
endfunction


" Handles Python block indentation.  This probably needs a lot more work.
function! s:indent_handler.block(line, block)
  if a:block[2] != 0
    " Special cases here.
    let text = getline(prevnonblank(a:line - 1))
    if a:line > 1 && a:line > a:block[2] && a:line <= a:block[3] && text =~ '\\$'
      " Line continuation with backslash on previous line
      return braceless#indent#space(a:block[2],
            \ braceless#get_var('braceless_cont_block', 2))[1]
    endif

    let prev = prevnonblank(a:line - 1)
    if text =~ '\\\s*$'
      return braceless#indent#space(prev, 1)[1]
    endif

    let text = getline(a:line)

    " Get a line above the current block
    let prev = prevnonblank(a:block[2] - 1)
    let pos = getpos('.')[1:2]

    " If the current line is at the block head, move to the line above to
    " determine a parent or sibling block
    if a:block[2] == a:line
      call cursor(prev, 0)
    elseif a:block[3] == a:line && text =~ '):'
      try
        return braceless#indent#non_block(a:line, a:line)
      catch /cont/
      endtry
    endif

    let pat = '^\s*'.braceless#get_pattern().start
    let block_head = braceless#scan_head(pat, 'b')[0]
    if block_head > a:block[2]
      " Special case for weirdly indented multi-line blocks
      let prev_block = braceless#get_block_lines(block_head)
      let prev_line = prevnonblank(a:line - 1)
      if prev_line > prev_block[1] || a:line - prev_line > 1
        throw 'cont'
      endif

      let [parent, _] = braceless#get_parent_block_lines(block_head)
      if prev_block[3] != prev_block[1]
            \ && parent[0] != 0 && a:line <= parent[1]
            \ && braceless#indent#level(parent[2], 1) == braceless#indent#level(a:line, 0)
        return braceless#indent#space(parent[2], 1)[1]
      endif
      return braceless#indent#space(block_head, 1)[1]
    endif
    call cursor(pos)

    if match(text, pat) != -1
      let line_kw = matchstr(text, '\K\+')
      return s:contextual_indent(a:line, line_kw)
    endif
  endif

  if a:line >= a:block[2]
    if getline(a:line - 1) =~ '\\$'
      if getline(a:line - 2) !~ '\\$'
        return braceless#indent#space(a:line - 1, 1)[1]
      endif
      return indent(a:line - 1)
    elseif a:line - 2 > a:block[2] && getline(a:line - 2) =~ '\\$'
      return braceless#indent#space(a:line - 2, 0)[1]
    endif
  endif

  " Fall back to the default block indent
  throw 'cont'
endfunction

function! s:indent_handler.docstring(line, docstr)
  let prev = prevnonblank(a:line - 1)
  if a:line == a:docstr[0] && getline(prev) =~ '\\$'
    return braceless#indent#space(prev, 1)[1]
  endif
  throw 'cont'
endfunction

let s:jump = '^\s*\%(def\|class\)\s*\zs\S\_.\{-}:\ze\s*\%(\_$\|#\)'

function! <SID>braceless_method_jump(vmode, direction, top)
  if a:vmode ==? 'v'
    normal! gv
  endif

  let pos = getpos('.')[1:2]
  let head = [0, 0]
  let c = v:count1

  if a:direction == 1 && a:top == 0 && braceless#scan_head(s:jump, 'nc') == pos
    " Sitting right on top of a match so it can't count.
    let c -= 1
  endif

  while c > 0
    let h = braceless#scan_head(s:jump, a:direction == -1 ? 'b' : '')
    if h[0] == 0
      break
    endif
    let head = h
    let c -= 1
  endwhile

  if head[0] == 0
    let head = braceless#scan_head(s:jump, a:direction == 1 ? 'cb' : 'c')
  endif

  call cursor(pos)

  if head[0] != 0
    if a:top
      execute 'normal! '.head[0].'G'.head[1].'|'
    else
      let block = braceless#get_block_lines(head[0], 1)
      if a:direction == -1 && block[1] >= pos[0]
        call cursor(head)
        let head = braceless#scan_head(s:jump, 'b')
        call cursor(pos)
        if head[0] != 0
          let block = braceless#get_block_lines(head[0], 1)
        endif
      elseif block[1] == pos[0]
        call cursor(head)
        let head = braceless#scan_head(s:jump, '')
        call cursor(pos)
        if head[0] != 0
          let block = braceless#get_block_lines(head[0], 1)
        endif
      endif

      if block[0] != 0
        execute 'normal! '.block[1].'G$'
      endif
    endif
  endif
endfunction


" Get the delimiters for a string at a cursor location.
function! braceless#python#string_delimiter(line, col)
  let saved = winsaveview()
  call cursor(a:line, a:col)
  " Not sure if this is genius or stupid.
  let delim_pos = braceless#validsearch('\_.', 'ncb', a:line)
  call winrestview(saved)

  if !delim_pos[0]
    return ['', '']
  endif

  let delim_text = getline(delim_pos[0])
  if strpart(delim_text, delim_pos[1], 3) =~ '"""\|'''''''
    return ['', '']
  endif

  let d1 = matchstr(strpart(delim_text, delim_pos[1]), '^\%([rub]*\)\?[''"]')
  let d2 = strpart(d1, len(d1) - 1)

  return [d1, d2]
endfunction


" Override the <enter> key.  Can be called with an optional argument that
" tells it to not add fancy things.
function! braceless#python#override_cr(...) abort
  if exists('b:braceless') && b:braceless.indent_enabled
    let pos = getpos('.')[1:2]
    let pos_byte = line2byte(pos[0]) + pos[1]
    let [col_head, col_tail] = braceless#collection_bounds()
    if col_head[0] != 0
      let col_head_byte = line2byte(col_head[0]) + col_head[1]
      let col_tail_byte = line2byte(col_tail[0]) + col_tail[1]
      let in_collection = pos_byte >= col_head_byte && (col_tail_byte == 0 || pos_byte <= col_tail_byte)
    else
      let in_collection = 0
    endif

    if get(g:, 'braceless_line_continuation', 1)
      let docstr = braceless#docstring_bounds()
      if docstr[0][0]
        let docstr_head_byte = line2byte(docstr[0][0]) + docstr[0][1]
        let docstr_tail_byte = line2byte(docstr[1][0]) + docstr[1][1]
        let in_docstr = pos_byte >= docstr_head_byte && (docstr_tail_byte == 0 || pos_byte < docstr_tail_byte)
      else
        let in_docstr = 0
      endif

      " In insert mode, the cursor is 1 character to the right when
      " considering where a string has ended.
      let at_end = pos[1] == col('$') - (mode() == 'i' ? 0 : 1)

      " Search for ending character since trailing spaces may have the
      " pythonSpaceError syntax group.
      if at_end
        call search('\S', 'cb', line('.'))
      endif

      let is_string = braceless#is_string(line('.'), col('.') - 1)
      call cursor(pos)

      if is_string
        let [d1, d2] = braceless#python#string_delimiter(line('.'), col('.'))
      else
        let d1 = ''
        let d2 = ''
      endif

      if !in_docstr && is_string && !at_end
            \ && d1 != '' && d2 != ''
            \ && get(g:, 'braceless_string_break', 1)
        let ret = d2
        if !in_collection
          let ret .= ' \'
        endif
        let whitespace = matchstr(getline(pos[0]), '^\s\+', pos[1] - 1)
        if whitespace != '' && !a:0
          " Move the cursor back before the whitespace
          let whitespace .= printf("\<c-o>%dh", len(whitespace))
        endif
        return ret."\<cr>".d1.whitespace
      endif

      if !is_string
        " Auto-insert backslash for line continuation if inside of a block head.
        " The caveat is that it needs to be a 'complete' block head.
        let [head, tail] = braceless#head_bounds()
        let head_byte = line2byte(head[0]) + head[1]
        let tail_byte = line2byte(tail[0]) + tail[1]
        let in_head = pos_byte > head_byte && (tail_byte == 0 || pos_byte <= tail_byte)
        if !in_collection
          let line_head = strpart(getline(pos[0]), 0, col('.') - 1)
          let line_tail = strpart(getline(pos[0]), col('.') - 1)
          let prev_line = getline(pos[0] - 1)
          if braceless#is_comment(line('.'), col('.')) && line_tail != ''
            if &l:formatoptions !~ 'r'
              return "\<cr># "
            endif
          elseif (in_head && line_head !~ '\\\s*$')
                \ || line_head =~ '\s*\%(=\|or\|and\)\s*$'
                \ || (line_head !~ '^\s*$' && line_tail !~ '^\s*$')
                \ || (line_head =~ '^\s*$' && prev_line =~ '\\$')
            let ret = "\\\<cr>"
            if line_head !~ '\s$'
              let ret = ' '.ret
            endif
            return ret
          endif
        endif
      endif
    endif

    if in_collection
          \ && get(b:, 'delimitMate_enabled', 0) && delimitMate#Get('expand_cr') == 2
          \ && search(s:call_pattern, 'nbeW') != pos[0]
      " delimitMate_expand_cr = 2 is great for assignments, but not for functions
      " and whatnot.
      return delimitMate#ExpandReturn()
    endif
  endif

  return "\<cr>"
endfunction


function! s:map(lhs, direction, top)
  execute 'nnoremap <silent> <buffer>' a:lhs ':<C-u> call <SID>braceless_method_jump("n",' a:direction ',' a:top ')<cr>'
  execute 'onoremap <silent> <buffer>' a:lhs ':<C-u> call <SID>braceless_method_jump("n",' a:direction ',' a:top ')<cr>'
  execute 'vnoremap <silent> <buffer>' a:lhs ':<C-u> call <SID>braceless_method_jump(visualmode(),' a:direction ',' a:top ')<cr>'
endfunction


function! braceless#python#setup_indent()
  setlocal indentkeys=!^F,o,O,<:>,0),0],0},=elif,=except
endfunction


function! braceless#python#init()
  call braceless#indent#add_handler('python', s:indent_handler)

  silent! inoremap <expr><unique><silent><buffer> <cr> braceless#python#override_cr()

  if get(g:braceless_format, 'join', 1)
    silent! nnoremap <unique> <silent> <buffer> J :<c-u>call braceless#python#format#join_lines('n')<cr>
    silent! vnoremap <unique> <silent> <buffer> J :<c-u>call braceless#python#format#join_lines('v')<cr>
  endif

  call s:map('[m', -1, 1)
  call s:map(']m', 1, 1)
  call s:map('[M', -1, 0)
  call s:map(']M', 1, 0)
endfunction
