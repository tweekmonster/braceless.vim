function! braceless#fold#expr(line)
  let block = braceless#get_block_lines(a:line)
  if type(block) != 3
    return 0
  endif

  let inner = get(b:braceless, 'fold_inner', 0)
  let i_n = braceless#indent#level(block[2], 1)

  if a:line != block[0] && a:line == block[3]
    return -1
  elseif a:line == block[0]
    return inner ? i_n - 1 : '>'.i_n
  elseif inner && a:line == block[0]+1
    return '>'.i_n
  elseif a:line == block[1]
    return '<'.i_n
  endif
  return i_n
endfunction
