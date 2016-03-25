let s:col_track = 0
let s:ignore_clean_skip = 0
let s:format_subs = []


function! s:clean_skip() abort
  if s:ignore_clean_skip
    return 0
  endif
  return braceless#is_skippable(line('.'), col('.'))
endfunction


function! s:clean_replace(match, replacement) abort
  if s:clean_skip()
    return a:match
  endif
  if col('.') < s:col_track
    let s:col_track -= len(a:match) - len(a:replacement)
  endif
  return a:replacement
endfunction


function! s:clean_strip(match) abort
  if s:clean_skip()
    return a:match
  endif
  let ret = substitute(a:match, '\_^\s\+\|\s\+\_$', '', 'g')
  if col('.') < s:col_track
    let s:col_track -= len(a:match) - len(ret)
  endif
  return ret
endfunction


function! s:clean_add_space(match1, match2) abort
  if s:clean_skip()
    return a:match1.a:match2
  endif
  let ret = a:match1.' '.a:match2
  if col('.') < s:col_track
    let s:col_track -= len(a:match) - len(ret)
  endif
  return ret
endfunction


function! s:clean_slice(match) abort
  if s:clean_skip()
    return a:match
  endif
  let ret = substitute(a:match, '\s*\([+\-\*/%]\)\s*', '\1', 'g')
  if col('.') < s:col_track
    let s:col_track -= len(a:match) - len(ret)
  endif
  return ret
endfunction


function! s:clean_join_string(match) abort
  if braceless#is_string(line('.'), col('.') + 1)
    return a:match
  endif
  if col('.') < s:col_track
    let s:col_track -= len(a:match)
  endif
  return ''
endfunction


" Clean the current line of line continuation characters, but ignores the last
" continuation character.
function! s:clean_line(strip_trailing_slash) abort
  let saved = winsaveview()
  let s:col_track = col('.')
  let tmp = @/

  " This is faster than a lot of search()es and normal commands, but can add
  " items to the search history.  These can't be straight up substitutions
  " because they have to test if the match is valid and readjust the cursor
  " column.

  if empty(s:format_subs)
    " Line continuations
    call add(s:format_subs, 's/\(\s*\\\s*\)\%(\_$\)\@!/\=s:clean_replace(submatch(1), '' '')/g')
    if get(g:braceless_format, 'clean_collections', 1)
      " Cleanup whitespace immediately inside collections
      call add(s:format_subs, 's/\(\%(\%((\|\[\|{\)\s\+\)\|\%(\s\+\%()\|]\|}\)\)\)/\=s:clean_strip(submatch(1))/g')
    endif
    if get(g:braceless_format, 'clean_commas', 1)
      " Add whitespace after commas
      call add(s:format_subs, 's/\(,\)\(\k\|''\|"\)/\=s:clean_add_space(submatch(1), submatch(2))/g')
    endif
    if get(g:braceless_format, 'clean_slices', 1)
      " Remove whitespace in slices
      call add(s:format_subs, 's/\[[^\[\]]\+\]/\=s:clean_slice(submatch(0))/g')
    endif
    if get(g:braceless_format, 'clean_dot', 1)
      " Remove spaces around dots
      call add(s:format_subs, 's/\s*\.\s*/\=s:clean_replace(submatch(0), ''.'')/g')
    endif
    if get(g:braceless_format, 'join_string', 1)
      " Join contiguous strings together
      call add(s:format_subs, 's/\([''"]\)\s*[urb]*\1/\=s:clean_join_string(submatch(0))/g')
    endif
    if get(g:braceless_format, 'clean_whitespace', 1)
      call add(s:format_subs, 's/\%(\_^ *\)\@<!\( \+\)/\=s:clean_replace(submatch(0), '' '')/g')
    endif

    " Excess trailing whitespace is always cleaned
    call add(s:format_subs, 's/\s\+$/\=s:clean_replace(submatch(1), '' '')/g')
  endif

  if a:strip_trailing_slash
    " Remove trailing line continuation
    call insert(s:format_subs, 's/\(\s*\\\)$/\=s:clean_replace(submatch(1), '''')/g', 1)
  endif

  " Don't use silent! below so that non-search errors are displayed.
  for s in s:format_subs
    try
      execute s
    catch /E486/
    endtry
  endfor

  call histdel('search', -1)
  let @/ = tmp

  call winrestview(saved)
  return s:col_track - 1
endfunction


function! braceless#python#format#join_lines(mode) abort
  if a:mode ==? 'v'
    normal! gv
  endif

  normal! J
  call s:clean_line(0)
endfunction
