" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

function! commandt#private#ListMatches() abort
  ruby $command_t.list_matches
endfunction

function! commandt#private#HandleKey(arg) abort
  ruby $command_t.handle_key
endfunction

function! commandt#private#Backspace() abort
  ruby $command_t.backspace
endfunction

function! commandt#private#Delete() abort
  ruby $command_t.delete
endfunction

function! commandt#private#AcceptSelection() abort
  ruby $command_t.accept_selection
endfunction

function! commandt#private#AcceptSelectionTab() abort
  ruby $command_t.accept_selection :command => $command_t.tab_command
endfunction

function! commandt#private#AcceptSelectionSplit() abort
  ruby $command_t.accept_selection :command => $command_t.split_command
endfunction

function! commandt#private#AcceptSelectionVSplit() abort
  ruby $command_t.accept_selection :command => $command_t.vsplit_command
endfunction

function! commandt#private#Quickfix() abort
  ruby $command_t.quickfix
endfunction

function! commandt#private#Refresh() abort
  ruby $command_t.refresh
endfunction

function! commandt#private#RemoveBuffer() abort
  ruby $command_t.remove_buffer
endfunction

function! commandt#private#ToggleFocus() abort
  ruby $command_t.toggle_focus
endfunction

function! commandt#private#Cancel() abort
  ruby $command_t.cancel
endfunction

function! commandt#private#SelectNext() abort
  ruby $command_t.select_next
endfunction

function! commandt#private#SelectPrev() abort
  ruby $command_t.select_prev
endfunction

function! commandt#private#Clear() abort
  ruby $command_t.clear
endfunction

function! commandt#private#ClearPrevWord() abort
  ruby $command_t.clear_prev_word
endfunction

function! commandt#private#CursorLeft() abort
  ruby $command_t.cursor_left
endfunction

function! commandt#private#CursorRight() abort
  ruby $command_t.cursor_right
endfunction

function! commandt#private#CursorEnd() abort
  ruby $command_t.cursor_end
endfunction

function! commandt#private#CursorStart() abort
  ruby $command_t.cursor_start
endfunction

function! commandt#private#RunAutocmd(cmd) abort
  if v:version > 703 || v:version == 703 && has('patch438')
    execute 'silent doautocmd <nomodeline> User ' . a:cmd
  else
    execute 'silent doautocmd User ' . a:cmd
  endif
endfunction
