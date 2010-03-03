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
    require 'command-t'
  rescue LoadError
    lib = "#{ENV['HOME']}/.vim/ruby"
    raise if $LOAD_PATH.include?(lib)
    $LOAD_PATH << lib
    retry
  end

  module Screen
    def self.lines
      VIM.evaluate('&lines').to_i
    end

    def self.columns
      VIM.evaluate('&columns').to_i
    end
  end # module Screen

  module VIM
    class Window
      def select
        return true if selected?
        initial = $curwin
        while true do
          VIM::command 'wincmd w'             # cycle through windows
          return true if $curwin == self      # have selected desired window
          return false if $curwin == initial  # have already looped through all
        end
      end

      def selected?
        $curwin == self
      end
    end # class Window

    def self.has_syntax?
      VIM.evaluate('has("syntax")') != '0'
    end

    def self.pwd
      VIM.evaluate('getcwd()')
    end

    # Escape a string for safe inclusion in a Vim single-quoted string
    # (single quotes escaped by doubling, everything else is literal)
    def self.escape_for_single_quotes str
      str.gsub "'", "''"
    end
  end

  module CommandT

    # Abuse the status line as a prompt.
    class Prompt
      attr_accessor :abbrev

      def initialize
        @abbrev     = ''  # abbreviation entered so far
        @col        = 0   # cursor position
        @has_focus  = false
      end

      # Erase whatever is displayed in the prompt line,
      # effectively disposing of the prompt
      def dispose
        VIM::command 'echo'
        VIM::command 'redraw'
      end

      # Clear any entered text.
      def clear!
        @abbrev = ''
        @col    = 0
        redraw
      end

      # Insert a character at (before) the current cursor position.
      def add! char
        left, cursor, right = abbrev_segments
        @abbrev = left + char + cursor + right
        @col += 1
        redraw
      end

      # Delete a character to the left of the current cursor position.
      def backspace!
        if @col > 0
          left, cursor, right = abbrev_segments
          @abbrev = left.chop! + cursor + right
          @col -= 1
          redraw
        end
      end

      # Delete a character at the current cursor position.
      def delete!
        if @col < @abbrev.length
          left, cursor, right = abbrev_segments
          @abbrev = left + right
          redraw
        end
      end

      def cursor_left
        if @col > 0
          @col -= 1
          redraw
        end
      end

      def cursor_right
        if @col < @abbrev.length
          @col += 1
          redraw
        end
      end

      def cursor_end
        if @col < @abbrev.length
          @col = @abbrev.length
          redraw
        end
      end

      def cursor_start
        if @col != 0
          @col = 0
          redraw
        end
      end

      def redraw
        if @has_focus
          prompt_highlight = 'Comment'
          normal_highlight = 'None'
          cursor_highlight = 'Underlined'
        else
          prompt_highlight = 'NonText'
          normal_highlight = 'NonText'
          cursor_highlight = 'NonText'
        end
        left, cursor, right = abbrev_segments
        components = [prompt_highlight, '>>', 'None', ' ']
        components += [normal_highlight, left] unless left.empty?
        components += [cursor_highlight, cursor] unless cursor.empty?
        components += [normal_highlight, right] unless right.empty?
        components += [cursor_highlight, ' '] if cursor.empty?
        set_status *components
      end

      def focus
        unless @has_focus
          @has_focus = true
          redraw
        end
      end

      def unfocus
        if @has_focus
          @has_focus = false
          redraw
        end
      end

    private

      # Returns the @abbrev string divided up into three sections, any of
      # which may actually be zero width, depending on the location of the
      # cursor:
      #   - left segment (to left of cursor)
      #   - cursor segment (character at cursor)
      #   - right segment (to right of cursor)
      def abbrev_segments
        left    = @abbrev[0, @col]
        cursor  = @abbrev[@col, 1]
        right   = @abbrev[(@col + 1)..-1] || ''
        [left, cursor, right]
      end

      def set_status *args
        # see ':help :echo' for why forcing a redraw here helps
        # prevent the status line from getting inadvertantly cleared
        # after our echo commands
        VIM::command 'redraw'
        while (highlight = args.shift) and  (text = args.shift) do
          text = VIM::escape_for_single_quotes text
          VIM::command "echohl #{highlight}"
          VIM::command "echon '#{text}'"
        end
        VIM::command 'echohl None'
      end
    end # class Prompt

    class MatchWindow
      @@selection_marker  = '> '
      @@marker_length     = @@selection_marker.length
      @@unselected_marker = ' ' * @@marker_length

      def initialize options = {}
        @prompt = options[:prompt]

        # create match window and set it up
        [
          'silent! botright 1split GoToFile',
          'setlocal bufhidden=delete',  # delete buf when no longer displayed
          'setlocal buftype=nofile',    # buffer is not related to any file
          'setlocal nomodifiable',      # prevent manual edits
          'setlocal noswapfile',        # don't create a swapfile
          'setlocal nowrap',            # don't soft-wrap
          'setlocal nonumber',          # don't show line numbers
          'setlocal foldcolumn=0',      # don't show a fold column at side
          'setlocal nocursorline',      # don't highlight line cursor is on
          'setlocal nospell',           # spell-checking off
          'setlocal nobuflisted',       # don't show up in the buffer list
          'setlocal textwidth=0'        # don't hard-wrap (break long lines)
        ].each { |command| VIM::command command }

        # sanity check: make sure the buffer really was created
        raise "Can't find buffer" unless $curbuf.name.match /GoToFile/

        # global settings (must manually save and restore)
        @settings = Settings.new
        @settings.save
        VIM::set_option 'timeoutlen=0'    # respond immediately to mappings
        VIM::set_option 'nohlsearch'      # don't highlight search strings
        VIM::set_option 'noinsertmode'    # don't make Insert mode the default
        VIM::set_option 'noshowcmd'       # don't show command info on last line
        VIM::set_option 'nolist'          # don't use List mode (visible tabs etc)
        VIM::set_option 'report=9999'     # don't show "X lines changed" reports
        VIM::set_option 'sidescroll=0'    # don't sidescroll in jumps
        VIM::set_option 'sidescrolloff=0' # don't sidescroll automatically

        # syntax coloring
        if VIM::has_syntax?
          VIM::command "syntax match CommandTSelection \"^#{@@selection_marker}.\\+$\""
          VIM::command 'syntax match CommandTNoEntries "^-- NO MATCHES --$"'
          VIM::command 'highlight link CommandTSelection Visual'
          VIM::command 'highlight link CommandTNoEntries Error'
          VIM::evaluate 'clearmatches()'
        end

        # hide cursor
        @cursor_highlight = get_cursor_highlight
        hide_cursor

        @has_focus  = false
        @selection  = nil
        @abbrev     = ''
        @window     = $curwin
        @buffer     = $curbuf
      end

      def close
        VIM::command "bwipeout! #{@buffer.number}"
        @settings.restore
        @prompt.dispose
        show_cursor
      end

      def add! char
        @abbrev += char
      end

      def backspace!
        @abbrev.chop!
      end

      def select_next
        if @selection < @matches.length - 1
          @selection += 1
          print_match(@selection - 1) # redraw old selection (removes marker)
          print_match(@selection)     # redraw new selection (adds marker)
        else
          # (possibly) loop or scroll
        end
      end

      def select_prev
        if @selection > 0
          @selection -= 1
          print_match(@selection + 1) # redraw old selection (removes marker)
          print_match(@selection)     # redraw new selection (adds marker)
        else
          # (possibly) loop or scroll
        end
      end

      def matches= matches
        if matches != @matches
          @matches =  matches
          @selection = 0
          print_matches
        end
      end

      def focus
        unless @has_focus
          @has_focus = true
          if VIM::has_syntax?
            VIM::command 'highlight link CommandTSelection Search'
          end
        end
      end

      def unfocus
        if @has_focus
          @has_focus = false
          if VIM::has_syntax?
            VIM::command 'highlight link CommandTSelection Visual'
          end
        end
      end

      def find char
        # is this a new search or the continuation of a previous one?
        now = Time.now
        if @last_key_time.nil? or @last_key_time < (now - 0.5)
          @find_string = char
        else
          @find_string += char
        end
        @last_key_time = now

        # see if there's anything up ahead that matches
        @matches[@selection..-1].each_with_index do |match, idx|
          if match[0, @find_string.length] == @find_string
            @selection += idx
            print_match(@selection - idx) # redraw old selection (removes marker)
            print_match(@selection)       # redraw new selection (adds marker)
            break
          end
        end
      end

    private

      def match_text_for_idx idx
        match = truncated_match @matches[idx]
        if idx == @selection
          prefix = @@selection_marker
          suffix = padding_for_selected_match match
        else
          prefix = @@unselected_marker
          suffix = ''
        end
        prefix + match + suffix
      end

      # Print just the specified match.
      def print_match idx
        return unless Window.select(@window)
        unlock
        @buffer[idx + 1] = match_text_for_idx idx
        lock
      end

      # Print all matches.
      def print_matches
        return unless Window.select(@window)
        unlock
        clear
        match_count = @matches.length
        actual_lines = 1
        @window_width = @window.width # update cached value
        if match_count == 0
          @window.height = actual_lines
          @buffer[1] = '-- NO MATCHES --'
        else
          max_lines = Screen.lines - 5
          max_lines = 1 if max_lines < 0
          actual_lines = match_count > max_lines ? max_lines : match_count
          @window.height = actual_lines
          (1..actual_lines).each do |line|
            idx = line - 1
            if @buffer.count >= line
              @buffer[line] = match_text_for_idx idx
            else
              @buffer.append line - 1, match_text_for_idx(idx)
            end
          end
        end

        # delete excess lines
        while (line = @buffer.count) > actual_lines do
          @buffer.delete line
        end
        lock
      end

      # Prepare padding for match text (trailing spaces) so that selection
      # highlighting extends all the way to the right edge of the window.
      def padding_for_selected_match str
        len = str.length
        if len >= @window_width - @@marker_length
          ''
        else
          ' ' * (@window_width - @@marker_length - len)
        end
      end

      # Convert "really/long/path" into "really...path" based on available
      # window width.
      def truncated_match str
        len = str.length
        available_width = @window_width - @@marker_length
        return str if len <= available_width
        left = (available_width / 2) - 1
        right = (available_width / 2) - 2 + (available_width % 2)
        str[0, left] + '...' + str[-right, right]
      end

      def clear
        # range = % (whole buffer)
        # action = d (delete)
        # register = _ (black hole register, don't record deleted text)
        VIM::command 'silent %d _'
      end

      def get_cursor_highlight
        # as :highlight returns nothing and only prints,
        # must redirect its output to a variable
        VIM::command 'silent redir => g:command_t_cursor_highlight'

        # force 0 verbosity to ensure origin information isn't printed as well
        VIM::command 'silent 0verbose highlight Cursor'
        VIM::command 'silent redir END'

        # there are 3 possible formats to check for, each needing to be
        # transformed in a certain way in order to reapply the highlight:
        #   Cursor xxx guifg=bg guibg=fg      -> :hi! Cursor guifg=bg guibg=fg
        #   Cursor xxx links to SomethingElse -> :hi! link Cursor SomethingElse
        #   Cursor xxx cleared                -> :hi! clear Cursor
        highlight = VIM::evaluate 'g:command_t_cursor_highlight'
        if highlight =~ /^Cursor\s+xxx\s+links to (\w+)/
          "link Cursor #{$~[1]}"
        elsif highlight =~ /^Cursor\s+xxx\s+cleared/
          'clear Cursor'
        elsif highlight =~ /Cursor\s+xxx\s+(.+)/
          "Cursor #{$~[1]}"
        else # last resort fallback
          'Cursor guifg=bg guibg=fg'
        end
      end

      def hide_cursor
        VIM::command 'highlight! Cursor NONE'
      end

      def show_cursor
        VIM::command "highlight! #{@cursor_highlight}"
      end

      def lock
        VIM::command 'setlocal nomodifiable'
      end

      def unlock
        VIM::command 'setlocal modifiable'
      end
    end

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
        limit = Screen.lines - 5
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
