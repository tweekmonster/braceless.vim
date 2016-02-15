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

" Blocks to keep on the same indent level if the sibling above it matches
let s:block_siblings = {
      \   'else': ['if', 'for', 'try', 'elif', 'while', 'except'],
      \   'elif': ['if'],
      \   'except': ['try', 'except'],
      \   'finally': ['try', 'except', 'else']
      \ }


" Handles Python block indentation.  This probably needs a lot more work.
function! s:indent_handler.block(line, block)
  " Special cases here.
  let indent_delta = 1
  let text = getline(a:line)

  let prev = prevnonblank(a:block[2] - 1)
  let pos = getpos('.')[1:2]
  if a:block[2] == a:line
    call cursor(prev, 0)
  endif
  let block_head = search(s:block_pattern, 'bcnW')
  call cursor(pos)

  if prev != block_head && match(text, s:block_pattern) != -1
    " The current line matches a block pattern
    let indent_delta = 0
    let line_kw = matchstr(text, '\K\+')

    if block_head == 0
      throw 'cont'
    endif

    let block_kw = matchstr(getline(block_head), '\K\+')

    if has_key(s:block_siblings, line_kw)
      let siblings = s:block_siblings[line_kw]

      " No sibling was found for this line, assume it should be indented past
      " the previous block
      if index(siblings, block_kw) == -1
        let indent_delta = 1
      else
        " So, it does hav a sibling.  Find one that's on the same indent level
        " to see if it should actually be moved from where it is.
        let [indent_char, indent_len] = braceless#indent#space(a:line, 0)
        call cursor(prevnonblank(a:line - 1), 0)
        let prev_block = search('^'.indent_char.'\{'.indent_len.'}\%('.join(siblings, '\|').'\)', 'ncbW')
        if prev_block != 0
          " It was found, use its line for the indent level
          let block_head = prev_block
          let indent_delta = 0
        endif
      endif
    else
      throw 'cont'
    endif
  else
    throw 'cont'
  endif

  return braceless#indent#space(block_head, indent_delta)[1]
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
    silent! imap <unique> <buffer> <cr> <c-r>=<SID>override_delimitMate_cr()<cr>
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
