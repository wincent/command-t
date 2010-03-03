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

  module CommandT

    # Convenience class for saving and restoring global settings.
    class Settings
      def save
        @timeoutlen     = get_number 'timeoutlen'
        @report         = get_number 'report'
        @sidescroll     = get_number 'sidescroll'
        @sidescrolloff  = get_number 'sidescrolloff'
        @splitbelow     = get_bool 'splitbelow'
        @hlsearch       = get_bool 'hlsearch'
        @insertmode     = get_bool 'insertmode'
        @showcmd        = get_bool 'showcmd'
        @list           = get_bool 'list'
      end

      def restore
        set_number 'timeoutlen', @timeoutlen
        set_number 'report', @report
        set_number 'sidescroll', @sidescroll
        set_number 'sidescrolloff', @sidescrolloff
        set_bool 'splitbelow', @splitbelow
        set_bool 'hlsearch', @hlsearch
        set_bool 'insertmode', @insertmode
        set_bool 'showcmd', @showcmd
        set_bool 'list', @list
      end

    private

      def get_number setting
        VIM::evaluate "&#{setting}"
      end

      def get_bool setting
        VIM::evaluate("&#{setting}") == '1'
      end

      def set_number setting, value
        VIM::set_option "#{setting}=#{value}"
      end

      def set_bool setting, value
        if value
          VIM::set_option setting
        else
          VIM::set_option "no#{setting}"
        end
      end
    end

    class Controller
      def initialize
        @prompt = Prompt.new
        @scanner = CommandT::Base.new
      end

      def show
        @scanner.path   = VIM::pwd
        @initial_window = $curwin
        @initial_buffer = $curbuf
        @match_window   = MatchWindow.new :prompt => @prompt
        @focus          = @prompt
        @prompt.focus
        register_for_key_presses
        clear # clears prompt and list matches
      end

      def hide
        @match_window.close
        if @initial_window.select
          VIM::command "silent b #{@initial_buffer.number}"
        end
      end

      def flush
        @scanner.flush
      end

      def key_pressed
        key = VIM::evaluate('a:arg').to_i.chr
        if @focus == @prompt
          @prompt.add! key
          list_matches
        else
          @match_window.find key
        end
      end

      def backspace_pressed
        if @focus == @prompt
          @prompt.backspace!
          list_matches
        end
      end

      def delete_pressed
        if @focus == @prompt
          @prompt.delete!
          list_matches
        end
      end

      def accept_selection
        selection = @match_window.selection
        hide
        open_selection selection
      end

      def toggle_focus
        @focus.unfocus # old focus
        if @focus == @prompt
          @focus = @match_window
        else
          @focus = @prompt
        end
        @focus.focus # new focus
      end

      def cancel
        hide
      end

      def select_next
        @match_window.select_next
      end

      def select_prev
        @match_window.select_prev
      end

      def clear
        @prompt.clear!
        list_matches
      end

      def cursor_left
        @prompt.cursor_left if @focus == @prompt
      end

      def cursor_right
        @prompt.cursor_right if @focus == @prompt
      end

      def cursor_end
        @prompt.cursor_end if @focus == @prompt
      end

      def cursor_start
        @prompt.cursor_start if @focus == @prompt
      end

    private

      # Backslash-escape space, \, |, %, #, "
      def sanitize_path_string str
        # for details on escaping command-line mode arguments see: :h :
        # (that is, help on ":") in the Vim documentation.
        str.gsub(/[ \\|%#"]/, '\\\\\0')
      end

      def open_selection selection
        selection = sanitize_path_string selection
        VIM::command "silent e #{selection}"
      end

      def map key, function, param = nil
        VIM::command "noremap <silent> <buffer> #{key} " \
          ":call CommandT#{function}(#{param})<CR>"
      end

      def register_for_key_presses
        # "normal" keys (interpreted literally)
        numbers     = ('0'..'9').to_a.join
        lowercase   = ('a'..'z').to_a.join
        uppercase   = lowercase.upcase
        punctuation = '<>`@#~!"$%&/()=+*-_.,;:?\\\'{}[] ' # and space
        (numbers + lowercase + uppercase + punctuation).each_byte do |b|
          map "<Char-#{b}>", 'KeyPressed', b
        end

        # "special" keys
        map '<BS>',     'BackspacePressed'
        map '<Del>',    'DeletePressed'
        map '<CR>',     'AcceptSelection'
        # TODO: maps for opening in split windows, tabs etc
        map '<Tab>',    'ToggleFocus'
        map '<Esc>',    'Cancel'
        map '<C-c>',    'Cancel'
        map '<C-n>',    'SelectNext'
        map '<C-p>',    'SelectPrev'
        map '<C-j>',    'SelectNext'
        map '<C-k>',    'SelectPrev'
        map '<Down>',   'SelectNext'
        map '<Up>',     'SelectPrev'
        map '<C-u>',    'Clear'
        map '<Left>',   'CursorLeft'
        map '<Right>',  'CursorRight'
        map '<C-h>',    'CursorLeft'
        map '<C-l>',    'CursorRight'
        map '<C-e>',    'CursorEnd'
        map '<C-a>',    'CursorStart'
      end

      # Returns the desired maximum number of matches, based on available
      # vertical space.
      def match_limit
        limit = VIM::Screen.lines - 5
        limit < 0 ? 1 : limit
      end

      def list_matches
        matches = @scanner.sorted_matches_for @prompt.abbrev, :limit => match_limit
        @match_window.matches = matches
      end
    end # class Controller
  end # module commandT

  $command_t = CommandT::Controller.new
EOF
