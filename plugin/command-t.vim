" Copyright 2010-2014 Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

if exists("g:command_t_loaded") || &cp
  finish
endif
let g:command_t_loaded = 1

command CommandTBuffer call commandt#CommandTShowBufferFinder()
command CommandTJump call commandt#CommandTShowJumpFinder()
command CommandTMRU call commandt#CommandTShowMRUFinder()
command CommandTTag call commandt#CommandTShowTagFinder()
command -nargs=? -complete=dir CommandT call commandt#CommandTShowFileFinder(<q-args>)
command CommandTFlush call commandt#CommandTFlush()

if !hasmapto(':CommandT<CR>') && maparg('<Leader>t', 'n') == ''
  silent! nnoremap <unique> <silent> <Leader>t :CommandT<CR>
endif

if !hasmapto(':CommandTBuffer<CR>') && maparg('<Leader>b', 'n') == ''
  silent! nnoremap <unique> <silent> <Leader>b :CommandTBuffer<CR>
endif

if !has('ruby')
  finish
endif
