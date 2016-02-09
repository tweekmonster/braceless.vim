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
