function! s:clear_folds(line, until) abort
  let saved = winsaveview()
  call cursor(a:line, 0)
  while foldlevel(a:line) > a:until
    normal! zd
  endwhile
  call winrestview(saved)
endfunction


function! s:fold_block(block) abort
  let pattern = braceless#get_pattern()
  let saved = winsaveview()
  let c_line = a:block[0]
  let block = a:block

  let last_block = block
  while c_line < a:block[1]
    execute 'keepjumps normal! '.block[0].'GV'.block[1].'Gzfzo'
    call cursor(block[3] + 1, 1)
    let n_line = braceless#scan_head(pattern.fold, 'nce')[0]
    if n_line > block[3] && n_line <= block[1] && foldlevel(n_line) > foldlevel(block[0])
      " If the next block is inside the previous one and it has a different
      " fold level, delete it.
      call s:clear_folds(n_line, foldlevel(block[0]))
    endif
    if n_line < c_line
      break
    endif
    let block = braceless#get_block_lines(n_line, 0, 1)
    if block == last_block
      break
    endif
    let c_line = n_line
    let last_block = block
  endwhile

  call winrestview(saved)
endfunction


function! s:fold_lines(top, bottom) abort
  let top = a:top > 0 ? a:top : 1
  let bottom = a:bottom > 0 ? a:bottom : line('$')
  call s:clear_folds(top, 0)
  call s:clear_folds(bottom, 0)
  if bottom - top > 1
    execute 'keepjumps normal! '.top.'GV'.bottom.'Gzfzo'
  else
    let s:fold_err = 'Not enough lines to fold'
  endif
endfunction


function! s:do_fold(line, recursive, count) abort
  if foldlevel(a:line) > 0
    if a:recursive
      let keystroke = 'zC'
    else
      let keystroke = 'zc'
    endif
    execute 'silent! normal! '.a:count.keystroke
  else
    echohl WarningMsg
    echo 'E490:' s:fold_err
    echohl None
  endif
endfunction


function! braceless#fold#close(line, recursive) abort
  let s:fold_err = 'No fold found'
  let cmd_count = v:count1

  let docstring = braceless#docstring(a:line)
  if docstring[0] != 0 && docstring[1] != 0 && docstring[1] - docstring[0] > 1
    call s:fold_lines(docstring[0], docstring[1])
    call s:do_fold(a:line, a:recursive, cmd_count)
    return
  endif

  let [col_head, col_tail] = braceless#collection_bounds()
  if col_head[0] != 0 && col_tail[0] != 0 && col_tail[0] - col_head[0] > 1
    if getline(col_head[0]) =~ '\%(=\|:\)\s*(\|{\|\['
      call s:fold_lines(col_head[0], col_tail[0])
      call s:do_fold(a:line, a:recursive, cmd_count)
      return
    endif
  endif

  let c_line = prevnonblank(a:line)
  let block = braceless#get_block_lines(c_line, 0, 1)
  if block[0] != 0 && a:line >= block[0] && a:line <= block[1]
    let level = braceless#indent#level(block[2], 1)
    let fold_level = foldlevel(block[2])
    let bottom_fold_level = foldlevel(block[1])
  else
    let level = braceless#indent#level(c_line, 1)
    let fold_level = foldlevel(a:line)
    let bottom_fold_level = fold_level
  endif
  let fold_diff = abs(level - fold_level)

  let saved = winsaveview()

  if fold_level == 0
    let pattern = braceless#get_pattern()
    let pat = '^'.pattern.fold

    let start = braceless#scan_head(pat, 'ncb')[0]

    if start == 0
      call s:fold_lines(1, braceless#scan_head(pattern.fold, 'n')[0] - 1)
    else
      let block = braceless#get_block_lines(start, 0, 1)

      if a:line > block[1]
        " Special case for lines that are outside of the found block
        call s:fold_lines(block[1] + 1, braceless#scan_head(pattern.fold, 'n')[0] - 1)
      else
        call s:fold_block(block)
      endif
    endif
  elseif fold_level != level || fold_level != bottom_fold_level || a:line != c_line
    " Must be a new block that wasn't folded before
    let pattern = braceless#get_pattern()
    let indent_len = (level - 1) * &sw
    let pat = '^\s\{'.indent_len.'}'.pattern.fold

    let start = braceless#scan_head(pat, 'ncb')[0]
    if start == 0
      let start = 1
    endif

    call s:clear_folds(start, level - 1)

    let block = braceless#get_block_lines(start, 0, 1)
    if block[0] == 0
      let bottom = braceless#scan_head(pattern.fold, 'n')[0] - 1
      if a:line >= start && a:line <= bottom
        call s:fold_lines(start, bottom)
      endif
    elseif a:line >= block[0] && a:line <= block[1]
      call s:fold_block(block)
    endif
  endif

  call winrestview(saved)
  call s:do_fold(c_line, a:recursive, cmd_count)
endfunction


function! s:no_manual_msg()
  echohl Title
  echon 'Braceless:'
  echohl None
  echon ' omit '
  echohl Keyword
  echon '+fold'
  echohl None
  echon ' if you want to control manual folds'
endfunction


function! braceless#fold#enable_fast()
  setlocal foldmethod=manual
  for keystroke in ['zf', 'zF', 'zd', 'zD', 'zE']
    execute 'nnoremap <silent> <buffer> '.keystroke.' :<C-u>call <sid>no_manual_msg()<cr>'
  endfor
  vnoremap <silent> zf :<C-u>call <sid>no_manual_msg()<cr>
  nnoremap <silent> <buffer> zc :<C-u>call braceless#fold#close(line('.'), 0)<cr>
  nnoremap <silent> <buffer> zC :<C-u>call braceless#fold#close(line('.'), 1)<cr>
endfunction


" Below is the slower, deprecated method for folding

" Build a cache of the entire buffer.  This decreases the time impact of
" loading a large file by preemptively scanning all foldable blocks.
function! s:build_cache()
  let saved = winsaveview()
  let pattern = braceless#get_pattern()
  call cursor(1, 1)
  let head = braceless#scan_head(pattern.fold, 'e')[0]

  while head != 0
    if empty(b:braceless.fold_cache)
      let b:braceless.fold_cache[0] = []
      call add(b:braceless.fold_cache[0], [1, head - 1, 1, 1])
    endif

    let block = braceless#get_block_lines(head, 1)
    let level = braceless#indent#level(block[2], 0)

    if !has_key(b:braceless.fold_cache, level)
      let b:braceless.fold_cache[level] = []
    endif

    call add(b:braceless.fold_cache[level], block)
    let head = braceless#scan_head(pattern.fold, 'e')[0]
    if head == 0
      let l = nextnonblank(line('.'))
      if l != 0
        call add(b:braceless.fold_cache[0], [l, line('$'), l, l])
        break
      endif
    endif
  endwhile

  call winrestview(saved)
endfunction


" Finds a cached block by searching decreasing indent levels.
" Note: This might need to be refactored.
function! s:cached_block(line)
  let block = [0, 0, 0, 0]
  let level = braceless#indent#level(prevnonblank(a:line), 1)
  while level >= 0
    if has_key(b:braceless.fold_cache, level)
      for b in b:braceless.fold_cache[level]
        if a:line >= b[0] && a:line <= b[1]
          let block = b
          let level = -1
          break
        elseif a:line > b[1]
          " Below the block, take it in case there are no matches (such as
          " blank lines)
          let block = b
        endif
      endfor
    endif
    let level -= 1
  endwhile
  return block
endfunction


function! braceless#fold#expr(line)
  " Usage of the cache is tracked with the b:changedtick variable.  Enabling
  " braceless sets fold_changedtick to the next change tick.  Once the buffer
  " is loaded and the folds are set, b:changedtick increments and invalidates
  " the cache.
  "
  " From this point, changes made to the buffer will only update the folds for
  " lines that are affected by the change.  Changes that causes a large number
  " of lines to be updated (such as indenting a big block) will still be a
  " little slow.
  if b:braceless.fold_changedtick < b:changedtick
    if !empty(b:braceless.fold_cache)
      let b:braceless.fold_cache = {}
    endif
    let saved = winsaveview()
    let pattern = braceless#get_pattern()
    call cursor(a:line, col([a:line, '$']))
    let head = braceless#scan_head(pattern.fold, 'nb')[0]
    if head == 0
      let head = braceless#scan_head(pattern.fold, 'n')[0]
      let block = [1, head - 1, 1, 1]
    else
      let block = braceless#get_block_lines(head)
    endif
    call winrestview(saved)
  else
    if empty(b:braceless.fold_cache)
      call s:build_cache()
    endif
    let block = s:cached_block(a:line)
  endif

  if type(block) != 3 || block[0] == 0
    return 0
  endif

  let inner = get(b:braceless, 'fold_inner', 0)
  let i_n = braceless#indent#level(block[2], 1)
  let end = nextnonblank(block[1] + 1) - 1

  if a:line != block[0] && a:line == block[3]
    return -1
  elseif a:line == block[0]
    return inner ? i_n - 1 : '>'.i_n
  elseif inner && a:line == block[0]+1
    return '>'.i_n
  elseif a:line == end
    return '<'.i_n
  endif
  return i_n
endfunction
