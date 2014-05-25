" Copyright 2010-2014 Wincent Colaiuta. All rights reserved.
"
" Redistribution and use in source and binary forms, with or without
" modification, are permitted provided that the following conditions are met:
"
" 1. Redistributions of source code must retain the above copyright notice,
"    this list of conditions and the following disclaimer.
" 2. Redistributions in binary form must reproduce the above copyright notice,
"    this list of conditions and the following disclaimer in the documentation
"    and/or other materials provided with the distribution.
"
" THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
" IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
" ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
" LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
" CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
" SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
" INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
" CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
" ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
" POSSIBILITY OF SUCH DAMAGE.

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
