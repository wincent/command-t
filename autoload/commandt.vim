" Copyright 2010-2014 Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

if exists("g:command_t_autoloaded") || &cp
  finish
endif
let g:command_t_autoloaded = 1

function! s:CommandTRubyWarning()
  echohl WarningMsg
  echo "command-t.vim requires Vim to be compiled with Ruby support"
  echo "For more information type:  :help command-t"
  echohl none
endfunction

function! commandt#CommandTShowBufferFinder()
  if has('ruby')
    ruby $command_t.show_buffer_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTShowFileFinder(arg)
  if has('ruby')
    ruby $command_t.show_file_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTShowJumpFinder()
  if has('ruby')
    ruby $command_t.show_jump_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTShowMRUFinder()
  if has('ruby')
    ruby $command_t.show_mru_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTShowTagFinder()
  if has('ruby')
    ruby $command_t.show_tag_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTFlush()
  if has('ruby')
    ruby $command_t.flush
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTLoad()
  if !has('ruby')
    call s:CommandTRubyWarning()
  endif
endfunction

if !has('ruby')
  finish
endif

function! CommandTListMatches()
  ruby $command_t.list_matches
endfunction

function! CommandTHandleKey(arg)
  ruby $command_t.handle_key
endfunction

function! CommandTBackspace()
  ruby $command_t.backspace
endfunction

function! CommandTDelete()
  ruby $command_t.delete
endfunction

function! CommandTAcceptSelection()
  ruby $command_t.accept_selection
endfunction

function! CommandTAcceptSelectionTab()
  ruby $command_t.accept_selection :command => $command_t.tab_command
endfunction

function! CommandTAcceptSelectionSplit()
  ruby $command_t.accept_selection :command => $command_t.split_command
endfunction

function! CommandTAcceptSelectionVSplit()
  ruby $command_t.accept_selection :command => $command_t.vsplit_command
endfunction

function! CommandTQuickfix()
  ruby $command_t.quickfix
endfunction

function! CommandTRefresh()
  ruby $command_t.refresh
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

function! CommandTClearPrevWord()
  ruby $command_t.clear_prev_word
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

" note that we only start tracking buffers from first (autoloaded) use of Command-T
augroup CommandTMRUBuffer
  autocmd BufEnter * ruby CommandT::MRU.touch
  autocmd BufDelete * ruby CommandT::MRU.delete
augroup END

ruby << EOF
  # require Ruby files
  begin
    require 'command-t'
    $command_t = CommandT::Controller.new
  rescue LoadError
    load_path_modified = false
    ::VIM::evaluate('&runtimepath').to_s.split(',').each do |path|
      lib = "#{path}/ruby"
      if !$LOAD_PATH.include?(lib) && File.exist?(lib)
        $LOAD_PATH << lib
        load_path_modified = true
      end
    end
    retry if load_path_modified

    # could get here if C extension was not compiled, or was compiled
    # for the wrong architecture or Ruby version
    $command_t = CommandT::Stub.new
  end
EOF
