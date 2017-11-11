" Copyright 2010-present Greg Hurrell. All rights reserved.
" Licensed under the terms of the BSD 2-clause license.

if exists('g:command_t_autoloaded') || &cp
  finish
endif
let g:command_t_autoloaded = 1

"
" Functions
"

function! s:RubyWarning() abort
  echohl WarningMsg
  echo 'command-t.vim requires Vim to be compiled with Ruby support'
  echo 'For more information type:  :help command-t'
  echohl none
endfunction

function! commandt#BufferFinder() abort
  if has('ruby')
    ruby $command_t.show_buffer_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#CommandFinder() abort
  if has('ruby')
    ruby $command_t.show_command_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#FileFinder(arg) abort
  if has('ruby')
    ruby $command_t.show_file_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#JumpFinder() abort
  if has('ruby')
    ruby $command_t.show_jump_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#MRUFinder() abort
  if has('ruby')
    ruby $command_t.show_mru_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#HelpFinder() abort
  if has('ruby')
    ruby $command_t.show_help_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#HistoryFinder() abort
  if has('ruby')
    ruby $command_t.show_history_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#LineFinder() abort
  if has('ruby')
    let g:CommandTCurrentBuffer=bufnr('%')
    ruby $command_t.show_line_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#SearchFinder() abort
  if has('ruby')
    ruby $command_t.show_search_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#TagFinder() abort
  if has('ruby')
    ruby $command_t.show_tag_finder
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#Flush() abort
  if has('ruby')
    ruby $command_t.flush
  else
    call s:RubyWarning()
  endif
endfunction

function! commandt#Load() abort
  if !has('ruby')
    call s:RubyWarning()
  endif
endfunction

" For possible use in status lines.
function! commandt#ActiveFinder() abort
  if has('ruby')
    ruby ::VIM::command "return '#{$command_t.active_finder}'"
  else
    return ''
  endif
endfunction

" For possible use in status lines.
function! commandt#Path() abort
  if has('ruby')
    ruby ::VIM::command "return '#{($command_t.path || '').gsub(/'/, "''")}'"
  else
    return ''
  endif
endfunction

" For possible use in status lines.
function! commandt#CheckBuffer(buffer_number) abort
  if has('ruby')
    execute 'ruby $command_t.return_is_own_buffer' a:buffer_number
  else
    return 0
  endif
endfunction

" visible == exists, loaded, listed and not hidden
" (buffer is opened in a window - in current or another tab)
function! s:BufVisible(buffer)
  " buffer is opened in current tab (quick check for current tab)
  if bufwinnr('^' . a:buffer . '$') != -1 | return 1 | end
  " buffer exists if it has been opened at least once (unless wiped)
  if !bufexists(a:buffer) | return 0 | end
  " buffer is not loaded when its last window is closed (`set nohidden` only)
  if !bufloaded(a:buffer) | return 0 | end
  " buffer is not listed when it's deleted
  if !buflisted(a:buffer) | return 0 | end

  let bufno = bufnr(a:buffer)
  let ls_buffers = ''

  redir => ls_buffers
  silent ls
  redir END

  " buffer is hidden when its last window is closed (`set hidden` only)
  for line in split(ls_buffers, "\n")
    let components = split(line)
    if components[0] == bufno
      return match(components[1], 'h') == -1
    endif
  endfor

  return 1
endfunction

function! commandt#GotoOrOpen(command_and_args) abort
  let l:command_and_args = split(a:command_and_args, '\v^\w+ \zs')
  let l:command = l:command_and_args[0]
  let l:file = l:command_and_args[1]

  " `bufwinnr()` doesn't see windows in other tabs, meaning we open them again
  " instead of switching to the other tab; but `bufname()` sees hidden
  " buffers, and if we try to open one of those, we get an unwanted split.
  if s:BufVisible(l:file)
    execute 'sbuffer ' . l:file
  else
    execute l:command . l:file
  endif
endfunction

if !has('ruby')
  finish
endif

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
      ext = "#{path}/ruby/command-t/ext"
      if !$LOAD_PATH.include?(ext) && File.exist?(ext)
        $LOAD_PATH << ext
        load_path_modified = true
      end
      lib = "#{path}/ruby/command-t/lib"
      if !$LOAD_PATH.include?(lib) && File.exist?(lib)
        $LOAD_PATH << lib
        load_path_modified = true
      end
    end
    retry if load_path_modified

    $command_t = CommandT::Stub.new
  end
EOF
