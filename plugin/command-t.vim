" command-t.vim
" Copyright 2010-2012 Wincent Colaiuta. All rights reserved.
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

if exists("g:command_t_loaded")
  finish
endif
let g:command_t_loaded = 1
let s:ruby_files_loaded = 0

command CommandTBuffer call <SID>CommandTShowBufferFinder()
command CommandTJump call <SID>CommandTShowJumpFinder()
command CommandTTag call <SID>CommandTShowTagFinder()
command -nargs=? -complete=dir CommandT call <SID>CommandTShowFileFinder(<q-args>)
command CommandTFlush call <SID>CommandTFlush()
command -nargs=+ CommandTRuby call <SID>CommandTRuby(<q-args>)

if !hasmapto(':CommandT<CR>')
  silent! nnoremap <unique> <silent> <Leader>t :CommandT<CR>
endif

if !hasmapto(':CommandTBuffer<CR>')
  silent! nnoremap <unique> <silent> <Leader>b :CommandTBuffer<CR>
endif

function s:CommandTRubyWarning()
  echohl WarningMsg
  echo "command-t.vim requires Vim to be compiled with Ruby support"
  echo "For more information type:  :help command-t"
  echohl none
endfunction

function s:CommandTShowBufferFinder()
  if has('ruby')
    CommandTRuby $command_t.show_buffer_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function s:CommandTShowFileFinder(arg)
  if has('ruby')
    call s:CommandTRuby(a:arg, '$command_t.show_file_finder')
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function s:CommandTShowJumpFinder()
  if has('ruby')
    ruby $command_t.show_jump_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function s:CommandTShowTagFinder()
  if has('ruby')
    ruby $command_t.show_tag_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function s:CommandTFlush()
  if has('ruby')
    CommandTRuby $command_t.flush
  else
    call s:CommandTRubyWarning()
  endif
endfunction

if !has('ruby')
  finish
endif

function CommandTHandleKey(arg)
  call s:CommandTRuby(a:arg, '$command_t.handle_key')
endfunction

function CommandTBackspace()
  CommandTRuby $command_t.backspace
endfunction

function CommandTDelete()
  CommandTRuby $command_t.delete
endfunction

function CommandTAcceptSelection()
  CommandTRuby $command_t.accept_selection
endfunction

function CommandTAcceptSelectionTab()
  CommandTRuby $command_t.accept_selection :command => 'tabe'
endfunction

function CommandTAcceptSelectionSplit()
  CommandTRuby $command_t.accept_selection :command => 'sp'
endfunction

function CommandTAcceptSelectionVSplit()
  CommandTRuby $command_t.accept_selection :command => 'vs'
endfunction

function CommandTToggleFocus()
  CommandTRuby $command_t.toggle_focus
endfunction

function CommandTCancel()
  CommandTRuby $command_t.cancel
endfunction

function CommandTSelectNext()
  CommandTRuby $command_t.select_next
endfunction

function CommandTSelectPrev()
  CommandTRuby $command_t.select_prev
endfunction

function CommandTClear()
  CommandTRuby $command_t.clear
endfunction

function CommandTCursorLeft()
  CommandTRuby $command_t.cursor_left
endfunction

function CommandTCursorRight()
  CommandTRuby $command_t.cursor_right
endfunction

function CommandTCursorEnd()
  CommandTRuby $command_t.cursor_end
endfunction

function CommandTCursorStart()
  CommandTRuby $command_t.cursor_start
endfunction

function s:CommandTRuby(arg, ...)
  if !s:ruby_files_loaded
    call s:LoadRubyFiles()
    let s:ruby_files_loaded = 1
  endif

  if a:0 == 0
    let ruby_code = a:arg
  else
    let ruby_code = a:1
  endif

  execute 'ruby ' . ruby_code
endfunction

function s:LoadRubyFiles()
  ruby << EOF
    # require Ruby files
    begin
      # prepare controller
      require 'command-t/vim'
      require 'command-t/controller'
      $command_t = CommandT::Controller.new
    rescue LoadError
      load_path_modified = false
      ::VIM::evaluate('&runtimepath').to_s.split(',').each do |path|
        lib = "#{path}/ruby"
        if !$LOAD_PATH.include?(lib) and File.exist?(lib)
          $LOAD_PATH << lib
          load_path_modified = true
        end
      end
      retry if load_path_modified

      # could get here if C extension was not compiled, or was compiled
      # for the wrong architecture or Ruby version
      require 'command-t/stub'
      $command_t = CommandT::Stub.new
    end
EOF
endfunction
