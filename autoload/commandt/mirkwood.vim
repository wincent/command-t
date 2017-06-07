" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

" Set up the original implementation Command-T engine, codenamed "mirkwood".
function! commandt#mirkwood#init() abort
  command! CommandTBuffer call commandt#BufferFinder()
  command! CommandTCommand call commandt#CommandFinder()
  command! CommandTHelp call commandt#HelpFinder()
  command! CommandTHistory call commandt#HistoryFinder()
  command! CommandTJump call commandt#JumpFinder()
  command! CommandTLine call commandt#LineFinder()
  command! CommandTMRU call commandt#MRUFinder()
  command! CommandTSearch call commandt#SearchFinder()
  command! CommandTTag call commandt#TagFinder()
  command! -nargs=? -complete=dir CommandT call commandt#FileFinder(<q-args>)
  command! CommandTFlush call commandt#Flush()
  command! CommandTLoad call commandt#Load()

  if !hasmapto('<Plug>(CommandT)') && maparg('<Leader>t', 'n') ==# ''
    nmap <unique> <Leader>t <Plug>(CommandT)
  endif
  nnoremap <silent> <Plug>(CommandT) :CommandT<CR>

  if !hasmapto('<Plug>(CommandTBuffer)') && maparg('<Leader>b', 'n') ==# ''
    nmap <unique> <Leader>b <Plug>(CommandTBuffer)
  endif
  nnoremap <silent> <Plug>(CommandTBuffer) :CommandTBuffer<CR>

  nnoremap <silent> <Plug>(CommandTHelp) :CommandTHelp<CR>
  nnoremap <silent> <Plug>(CommandTHistory) :CommandTHistory<CR>

  if has('jumplist')
    if !hasmapto('<Plug>(CommandTJump)') && maparg('<Leader>j', 'n') ==# ''
      nmap <unique> <Leader>j <Plug>(CommandTJump)
    endif
    nnoremap <silent> <Plug>(CommandTJump) :CommandTJump<CR>
  endif

  nnoremap <silent> <Plug>(CommandTCommand) :CommandTCommand<CR>
  nnoremap <silent> <Plug>(CommandTLine) :CommandTLine<CR>
  nnoremap <silent> <Plug>(CommandTMRU) :CommandTMRU<CR>
  nnoremap <silent> <Plug>(CommandTSearch) :CommandTSearch<CR>
  nnoremap <silent> <Plug>(CommandTTag) :CommandTTag<CR>
endfunction
