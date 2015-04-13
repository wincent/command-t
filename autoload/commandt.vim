" Copyright 2010-2015 Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

if exists('g:command_t_autoloaded') || &cp
  finish
endif
let g:command_t_autoloaded = 1

function! s:CommandTRubyWarning() abort
  echohl WarningMsg
  echo 'command-t.vim requires Vim to be compiled with Ruby support'
  echo 'For more information type:  :help command-t'
  echohl none
endfunction

function! commandt#CommandTShowBufferFinder() abort
  if has('ruby')
    ruby $command_t.show_buffer_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTShowFileFinder(arg) abort
  if has('ruby')
    ruby $command_t.show_file_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTShowJumpFinder() abort
  if has('ruby')
    ruby $command_t.show_jump_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTShowMRUFinder() abort
  if has('ruby')
    ruby $command_t.show_mru_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTShowTagFinder() abort
  if has('ruby')
    ruby $command_t.show_tag_finder
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTFlush() abort
  if has('ruby')
    ruby $command_t.flush
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function! commandt#CommandTLoad() abort
  if !has('ruby')
    call s:CommandTRubyWarning()
  endif
endfunction

" For possible use in status lines.
function! commandt#CommandTActiveFinder() abort
  if has('ruby')
    ruby ::VIM::command "return '#{$command_t.active_finder}'"
  else
    return ''
  endif
endfunction

" For possible use in status lines.
function! commandt#CommandTPath() abort
  if has('ruby')
    ruby ::VIM::command "return '#{($command_t.path || '').gsub(/'/, "''")}'"
  else
    return ''
  endif
endfunction

" For possible use in status lines.
function! commandt#CommandTCheckBuffer(buffer_number) abort
  if has('ruby')
    execute 'ruby $command_t.return_is_own_buffer' a:buffer_number
  else
    return 0
  endif
endfunction

if !has('ruby')
  finish
endif

function! CommandTListMatches() abort
  ruby $command_t.list_matches
endfunction

function! CommandTHandleKey(arg) abort
  ruby $command_t.handle_key
endfunction

function! CommandTBackspace() abort
  ruby $command_t.backspace
endfunction

function! CommandTDelete() abort
  ruby $command_t.delete
endfunction

function! CommandTAcceptSelection() abort
  ruby $command_t.accept_selection
endfunction

function! CommandTAcceptSelectionTab() abort
  ruby $command_t.accept_selection :command => $command_t.tab_command
endfunction

function! CommandTAcceptSelectionSplit() abort
  ruby $command_t.accept_selection :command => $command_t.split_command
endfunction

function! CommandTAcceptSelectionVSplit() abort
  ruby $command_t.accept_selection :command => $command_t.vsplit_command
endfunction

function! CommandTQuickfix() abort
  ruby $command_t.quickfix
endfunction

function! CommandTRefresh() abort
  ruby $command_t.refresh
endfunction

function! CommandTToggleFocus() abort
  ruby $command_t.toggle_focus
endfunction

function! CommandTCancel() abort
  ruby $command_t.cancel
endfunction

function! CommandTSelectNext() abort
  ruby $command_t.select_next
endfunction

function! CommandTSelectPrev() abort
  ruby $command_t.select_prev
endfunction

function! CommandTClear() abort
  ruby $command_t.clear
endfunction

function! CommandTClearPrevWord() abort
  ruby $command_t.clear_prev_word
endfunction

function! CommandTCursorLeft() abort
  ruby $command_t.cursor_left
endfunction

function! CommandTCursorRight() abort
  ruby $command_t.cursor_right
endfunction

function! CommandTCursorEnd() abort
  ruby $command_t.cursor_end
endfunction

function! CommandTCursorStart() abort
  ruby $command_t.cursor_start
endfunction

" note that we only start tracking buffers from first (autoloaded) use of Command-T
augroup CommandTMRUBuffer
  autocmd!
  autocmd BufEnter * ruby CommandT::MRU.touch
  autocmd BufDelete * ruby CommandT::MRU.delete
augroup END

ruby << EOF
  # require Ruby files
  begin
    require 'command-t'

    # Make sure we're running with the same version of Ruby that Command-T was
    # compiled with.
    patchlevel = defined?(RUBY_PATCHLEVEL) ? RUBY_PATCHLEVEL : nil
    if CommandT::Metadata::UNKNOWN == true || (
      CommandT::Metadata::EXPECTED_RUBY_VERSION == RUBY_VERSION &&
      CommandT::Metadata::EXPECTED_RUBY_PATCHLEVEL == patchlevel
    )
      require 'command-t/ext' # eager load, to catch compilation problems early
      $command_t = CommandT::Controller.new
    else
      $command_t = CommandT::Stub.new
    end
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

    $command_t = CommandT::Stub.new
  end
EOF
