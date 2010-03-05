" command-t.vim
" Copyright 2010 Wincent Colaiuta. All rights reserved.
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
"
" Largely derived from from Stephen Bach's lusty-explorer.vim plugin
" (http://www.vim.org/scripts/script.php?script_id=1890) version 2.1.1, which
" contains the following notice:
"
"    Copyright: Copyright (C) 2007-2009 Stephen Bach
"               Permission is hereby granted to use and distribute this code,
"               with or without modifications, provided that this copyright
"               notice is copied with it. Like anything else that's free,
"               lusty-explorer.vim is provided *as is* and comes with no
"               warranty of any kind, either expressed or implied. In no
"               event will the copyright holder be liable for any damages
"               resulting from the use of this software.

if exists("g:command_t_loaded")
  finish
endif
let g:command_t_loaded = 1

command CommandT :call <SID>CommandTShow()
command CommandTFlush :call <SID>CommandTFlush()

nmap <silent> <Leader>t :CommandT<CR>

function! s:CommandTShow()
  if has('ruby')
    ruby $command_t.show
  else
    echohl WarningMsg
    echo "command-t.vim requires Vim to be compiled with Ruby support"
    echohl none
  endif
endfunction

function! s:CommandTFlush()
  if has('ruby')
    ruby $command_t.flush
  else
    echohl WarningMsg
    echo "command-t.vim requires Vim to be compiled with Ruby support"
    echohl none
  endif
endfunction

if !has('ruby')
  finish
endif

function! CommandTKeyPressed(arg)
  ruby $command_t.key_pressed
endfunction

function! CommandTBackspacePressed()
  ruby $command_t.backspace_pressed
endfunction

function! CommandTDeletePressed()
  ruby $command_t.delete_pressed
endfunction

function! CommandTAcceptSelection()
  ruby $command_t.accept_selection
endfunction

function! CommandTAcceptSelectionTab()
  ruby $command_t.accept_selection :command => 'tabe'
endfunction

function! CommandTAcceptSelectionSplit()
  ruby $command_t.accept_selection :command => 'sp'
endfunction

function! CommandTAcceptSelectionVSplit()
  ruby $command_t.accept_selection :command => 'vs'
endfunction

function! CommandTToggleFocus()
  ruby $command_t.toggle_focus
endfunction

function! CommandTCancel()
  ruby $command_t.cancel
endfunction

function! CommandTSelectNext()
  ruby $command_t.select_next
endfunction

function! CommandTSelectPrev()
  ruby $command_t.select_prev
endfunction

function! CommandTClear()
  ruby $command_t.clear
endfunction

function! CommandTCursorLeft()
  ruby $command_t.cursor_left
endfunction

function! CommandTCursorRight()
  ruby $command_t.cursor_right
endfunction

function! CommandTCursorEnd()
  ruby $command_t.cursor_end
endfunction

function! CommandTCursorStart()
  ruby $command_t.cursor_start
endfunction

ruby << EOF
  begin
    require 'vim'
    require 'command-t'
  rescue LoadError
    lib = "#{ENV['HOME']}/.vim/ruby"
    raise if $LOAD_PATH.include?(lib)
    $LOAD_PATH << lib
    retry
  end

  $command_t = CommandT::Controller.new
EOF
