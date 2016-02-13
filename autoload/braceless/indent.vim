" Gets the indent level of a line and modifies it with a indent level delta.
function! braceless#indent#level(expr, delta)
  let indent_len = indent(a:expr)
  let d = 1
  if !&expandtab
    let indent_len = (indent_len / &ts) + a:delta
  else
    let indent_len += &sw * a:delta
    let d = &sw
  endif
  return max([0, indent_len]) / d
endfunction


" Gets the indent level (in characters) of a line and modifies it with a
" indent level delta.
function! braceless#indent#space(expr, delta)
  let indent_char = ' '
  let indent_len = indent(a:expr)
  if !&expandtab
    let indent_char = '\t'
    let indent_len = (indent_len / &ts) + a:delta
  else
    let indent_len += &sw * a:delta
  endif
  return [indent_char, max([0, indent_len])]
endfunction


" Indent
let s:str_skip = "synIDattr(synID(line('.'), col('.'), 1), 'name')"
                  \." =~ '\\(Comment\\|Todo\\|String\\)$'"
let s:collection = ['(\|{\|\[', ')\|}\|\]']


function! s:indent_non_blocks(line, prev)
  " Try collection pairs
  let col_head = searchpairpos(s:collection[0], '', s:collection[1], 'nbW', s:str_skip)
  if col_head[0] != a:line && col_head[0] > 0
    let col_tail = searchpairpos(s:collection[0], '', s:collection[1], 'ncW', s:str_skip)
    if col_head[0] == col_tail[0]
      " All on the same line
      throw 'cont'
    endif

    " If the line doesn't end with a pair start, line up with it
    if getline(col_head[0]) !~ '\%('.s:collection[0].'\)\s*$'
      return col_head[1]
    endif

    " The pair start is at the end of the line, indent past the pair start
    " line.
    let indent_delta = 1

    " TODO: Call out to a language specific function to decide what to do with
    " with indents between col_head and col_tail.
    " Also need to look into overriding delimit mate's behavior on block head
    " lines when `delimitMate_expand_cr = 2` is set.

    " Different indentation if we're on the line with the tail
    if a:line == col_tail[0]
      if getline(col_tail[0]) =~ '^\s*\%('.s:collection[1].'\)\+\s*$'
        let indent_delta = 0
      endif
    endif

    return braceless#indent#space(col_head[0], indent_delta)[1]
  endif

  " Try docstrings
  if braceless#is_string(a:prev) || getline(a:line) =~ '\%("""\|''''''\)'
    let docstr = braceless#docstring(a:line)
    if docstr[0] != 0
      if a:line == docstr[0] || a:line == docstr[1]
        let pattern = braceless#get_pattern()
        let block = search('^\s*'.pattern.start, 'nbW')
        return braceless#indent#space(block, 1)[1]
      endif

      let prev = prevnonblank(a:line - 1)
      return braceless#indent#space(prev, 0)[1]
    endif
  endif

  throw 'cont'
endfunction


function! braceless#indent#python(line)
  let prev = prevnonblank(a:line)

  try
    return s:indent_non_blocks(a:line, prev)
  catch /cont/
  endtry

  let block = braceless#get_block_lines(prev, 1)
  if block[2] == 0
    return -1
  endif

  if a:line - prev > 2 || a:line == block[2] || a:line == block[3]
    return braceless#indent#space(block[0], 0)[1]
  endif
  return braceless#indent#space(block[0], 1)[1]
endfunction
