" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

if exists('g:command_t_loaded') || &compatible
  finish
endif
let g:command_t_loaded = 1

command! CommandTBuffer call commandt#BufferFinder()
command! CommandTHelp call commandt#HelpFinder()
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

nnoremap <silent> <Plug>(CommandTHelp) :CommandTHelp<CR>

if has('jumplist')
  if !hasmapto('<Plug>(CommandTJump)') && maparg('<Leader>j', 'n') ==# ''
    nmap <unique> <Leader>j <Plug>(CommandTJump)
  endif
  nnoremap <silent> <Plug>(CommandTJump) :CommandTJump<CR>
endif

nnoremap <silent> <Plug>(CommandTMRU) :CommandTMRU<CR>
nnoremap <silent> <Plug>(CommandTTag) :CommandTTag<CR>
