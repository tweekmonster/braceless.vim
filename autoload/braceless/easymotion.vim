" EasyMotion for indent blocks
function! braceless#easymotion#blocks(vmode, direction)
  let [pattern, stop_pattern] = braceless#get_pattern()
  if empty(pattern)
    return
  endif

  let pat = '^\s*'
  if pattern !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= pattern

  if pattern !~ '\\ze'
    let pat .= '\ze'
  endif

  call EasyMotion#User(pat, a:vmode, a:direction, 1)
endfunction
