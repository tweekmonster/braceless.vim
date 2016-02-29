" Build a cache of the entire buffer.  This decreases the time impact of
" loading a large file by preemptively scanning all foldable blocks.
function! s:build_cache()
  let saved = winsaveview()
  let pattern = braceless#get_pattern()
  let pat = '^\s*'.pattern.start
  call cursor(1, 1)

  while 1
    let head = braceless#scan_head(pat, 'n')[0]
    if head == 0
      break
    endif

    let block = braceless#get_block_lines(head)
    let level = braceless#indent#level(block[2], 0)

    if !has_key(b:braceless.fold_cache, level)
      let b:braceless.fold_cache[level] = []
    endif

    call add(b:braceless.fold_cache[level], block)
    call cursor(head + 1, 1)
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
    let block = braceless#get_block_lines(a:line)
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
