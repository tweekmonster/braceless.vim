let s:indent_handler = {}
let s:call_pattern = '\S\+(\zs\_.\{-}\ze)'
let s:pattern = ''


" This function exists because the repetition below felt dirty.
function! s:get_block_indent(pattern, line, col_head, col_tail, lonely_head_indent)
  let head = search(a:pattern, 'bW')
  if head != 0
    if a:col_head[0] == head && getline(head) =~ '(\s*$'
      return braceless#indent#space(head, a:lonely_head_indent)[1]
    endif

    let tail = search(a:pattern, 'enW')
    if a:col_head[0] == head && a:col_tail[0] <= tail
      return a:col_head[1]
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

  let i = s:get_block_indent(s:pattern, a:line, a:col_head, a:col_tail, 2)
  if i != -1
    return i
  endif

  call cursor(pos)

  let i = s:get_block_indent(s:call_pattern, a:line, a:col_head, a:col_tail, 1)
  if i != -1
    return i
  endif

  call cursor(pos)

  if a:line == a:col_tail[0] && a:col_head[0] != a:col_tail[0]
    if getline(a:col_head[0]) !~ '\%((\|{\|\[\)\s*$'
      return a:col_head[1]
    endif
    return braceless#indent#space(a:col_head[0], 0)[1]
  endif

  throw 'cont'
endfunction


let s:block_pattern = '^\s*\%(if\|def\|for\|try\|elif\|else\|with\|class\|while\|except\|finally\)'


function! s:scan_parent(name, from, start, stop, exact)
  let [indent_char, indent_len] = braceless#indent#space(a:from, 0)
  let pat = '^'
  if a:stop
    let pat .= '\%>'.a:stop.'l\&'
  endif
  let pat .= '\%('.indent_char.'\{'
  if !a:exact
    let pat .= ','
  endif
  let pat .= indent_len.'}\%('.a:name.'\)\_.\{-}:\ze\s*\%(\_$\|#\)\)'
  let pos = getpos('.')[1:2]
  call cursor(a:start, col([a:start, '$']))
  let found = braceless#scan_head(pat, 'nbW')[0]
  call cursor(pos)
  return found
endfunction


" Indent based on the current block and its expected sibling
function! s:contextual_indent(line, kw)
  let found = 0
  let prev = prevnonblank(a:line - 1)

  if a:kw == 'else'
    let found = s:scan_parent('if\|try\|for\|elif\|while\|except', a:line, prev, 0, 0)
  elseif a:kw == 'elif'
    let found = s:scan_parent('if', a:line, prev, 0, 0)
  elseif a:kw == 'except'
    let found = s:scan_parent('try\|except', a:line, prev, 0, 0)
  elseif a:kw == 'finally'
    let found = s:scan_parent('try\|else\|except', a:line, prev, 0, 0)
  endif

  if found == 0
    throw 'cont'
  endif

  if a:kw == 'else' || a:kw == 'finally'
    " Blocks that must be unique within their set
    let other = s:scan_parent(a:kw, found, prev, found, 1)
    if other != 0 && other != a:line && other > found
      return s:contextual_indent(found, a:kw)
    endif
  elseif a:kw == 'elif'
    let other = s:scan_parent('else', found, prev, found, 1)
    if other != 0 && other != a:line && other > found
      return s:contextual_indent(found, a:kw)
    endif
  endif

  if found != 0
    let block = braceless#get_block_lines(found)
    if block[0] != block[1] && block[1] < prev
      throw 'cont'
    endif
  endif
  return braceless#indent#space(found, 0)[1]
endfunction


" Handles Python block indentation.  This probably needs a lot more work.
function! s:indent_handler.block(line, block)
  " Special cases here.
  let text = getline(a:line)

  " Get a line above the current block
  let prev = prevnonblank(a:block[2] - 1)
  let pos = getpos('.')[1:2]

  " If the current line is at the block head, move to the line above to
  " determine a parent or sibling block
  if a:block[2] == a:line
    call cursor(prev, 0)
  endif

  let pat = '^\s*'.braceless#get_pattern().start
  let block_head = braceless#scan_head(pat, 'b')[0]
  if block_head > a:block[2]
    let prev_block = braceless#get_block_lines(block_head)
    let prev_line = prevnonblank(a:line - 1)
    echomsg prev_block '-' prev_line
    if prev_line > prev_block[1]
      throw 'cont'
    endif
    return braceless#indent#space(block_head, 1)[1]
  endif
  call cursor(pos)

  if match(text, pat) != -1
    let line_kw = matchstr(text, '\K\+')
    return s:contextual_indent(a:line, line_kw)
  endif

  throw 'cont'
endfunction


" delimitMate_expand_cr = 2 is great for assignments, but not for functions
" and whatnot.
function! s:override_delimitMate_cr()
  if search(s:call_pattern, 'nbeW') != line('.')
    return delimitMate#ExpandReturn()
  endif
  return "\<cr>"
endfunction


function! s:check_delimitMate()
  if delimitMate#Get('expand_cr') == 2
    silent! imap <unique> <silent> <buffer> <cr> <c-r>=<SID>override_delimitMate_cr()<cr>
  endif
endfunction


function! braceless#python#init()
  let s:pattern = '^\s*'.(braceless#get_pattern().start)
  call braceless#indent#add_handler('python', s:indent_handler)
  autocmd User delimitMate_map call s:check_delimitMate()

  if &l:indentexpr =~ 'braceless#'
    setlocal indentkeys=!^F,o,O,<:>,0),0],0},=elif,=except
  endif
endfunction
