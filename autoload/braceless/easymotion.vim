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


" Easy motion for segments
function! braceless#easymotion#segments(vmode, direction)
  let segments = braceless#segments#visible()

  let top_lines = []
  let bottom_lines = []
  for segment in segments
    call add(top_lines, '\%'.segment[0].'l')
    call add(bottom_lines, '\%'.segment[1].'l')
  endfor

  let top_pat = join(top_lines, '\|')
  let bottom_pat = join(bottom_lines, '\|')
  let pat = '\%(\%('.top_pat.'\)\&\_^\s*\zs\S\)\|\%(\%('.bottom_pat.'\)\&\zs\S\_$\)'
  call EasyMotion#User(pat, a:vmode, a:direction, 1)
endfunction
