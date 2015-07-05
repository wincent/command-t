" Copyright 2010-2015 Greg Hurrell. All rights reserved.
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

if !hasmapto(':CommandT<CR>') && maparg('<Leader>t', 'n') ==# ''
  nnoremap <unique> <silent> <Leader>t :CommandT<CR>
endif

if !hasmapto(':CommandTBuffer<CR>') && maparg('<Leader>b', 'n') ==# ''
  nnoremap <unique> <silent> <Leader>b :CommandTBuffer<CR>
endif
