" Gets the indent level of a line and modifies it with a indent level delta.
function! braceless#indent#level(expr, delta)
  let i_n = indent(a:expr)
  let d = 1
  if !&expandtab
    let i_n = (i_n / &ts) + a:delta
  else
    let i_n += &sw * a:delta
    let d = &sw
  endif
  return max([0, i_n]) / d
endfunction


" Gets the indent level (in characters) of a line and modifies it with a
" indent level delta.
function! braceless#indent#space(expr, delta)
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


" Indent
let s:str_skip = "synIDattr(synID(line('.'), col('.'), 1), 'name')"
                  \." =~ '\\(Comment\\|Todo\\|String\\)$'"
let s:collection = ['(\|{\|\[', ')\|}\|\]']


function! s:indent_non_blocks(line, prev)
  " Try collection pairs
  let col_head = searchpairpos(s:collection[0], '', s:collection[1], 'nbW', s:str_skip)
  if col_head[0] != a:line && col_head[0] > 0
    let col_tail = searchpairpos(s:collection[0], '', s:collection[1], 'nW', s:str_skip)
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
    let i_n = 1
    if a:line == col_tail[0]
      if getline(col_tail[0]) =~ '^\s*\%('.s:collection[1].'\)\+\s*$'
        let i_n = 0
      endif
    endif
    return braceless#indent#space(col_head[0], i_n)[1]
  endif

  " Try docstrings
  if braceless#is_string(a:prev) || getline(a:line) =~ '\%("""\|''''''\)'
    let docstr = braceless#docstring(a:line)
    if docstr[0] != 0
      if a:line == docstr[0] || a:line == docstr[1]
        let [pattern, _] = braceless#get_pattern()
        let block = search('^\s*'.pattern, 'nbW')
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

  let block = braceless#get_block_lines(prev)
  if block[2] == 0
    return -1
  endif

  if a:line - prev > 2 || a:line == block[2] || a:line == block[3]
    return braceless#indent#space(block[0], 0)[1]
  endif
  return braceless#indent#space(block[0], 1)[1]
endfunction
