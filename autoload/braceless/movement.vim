" Jump to an *actual* meaningful block in Python!
function! braceless#movement#block(direction, vmode, by_indent, count)
  let pattern = braceless#get_pattern()

  if a:vmode != 'n'
    normal! gv
  endif

  let flags = ''
  if a:direction == -1
    let flags = 'b'
  endif

  let pat = '^'
  if a:by_indent
    let block = braceless#get_block_lines(line('.'))
    let [indent_char, indent_len] = braceless#indent#space(block[2], a:direction)
    let pat .= indent_char.'\{'.indent_len.'}'
  else
    let pat .= '\s*'
  endif

  if pattern.jump !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= pattern.jump

  let i = a:count
  while i > 0
    call braceless#scan_head(pat, flags.'e')
    let i -= 1
  endwhile
endfunction
