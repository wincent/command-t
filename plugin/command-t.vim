" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

if exists('g:command_t_loaded') || &compatible
  finish
endif
let g:command_t_loaded = 1

command! CommandTBuffer call commandt#BufferFinder()
command! CommandTJump call commandt#JumpFinder()
command! CommandTMRU call commandt#MRUFinder()
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

if has('jumplist')
  if !hasmapto('<Plug>(CommandTJump)') && maparg('<Leader>j', 'n') ==# ''
    nmap <unique> <Leader>j <Plug>(CommandTJump)
  endif
  nnoremap <silent> <Plug>(CommandTJump) :CommandTJump<CR>
endif
