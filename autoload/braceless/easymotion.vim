" EasyMotion for indent blocks
function! braceless#easymotion#blocks(vmode, direction)
  let pattern = braceless#get_pattern()

  let pat = '^\s*'
  if pattern.easymotion !~ '\\zs'
    let pat .= '\zs'
  endif
  let pat .= pattern.easymotion

  if pattern.easymotion !~ '\\ze'
    let pat .= '\ze'
  endif

  call EasyMotion#User(pat, a:vmode, a:direction, 1)
endfunction
