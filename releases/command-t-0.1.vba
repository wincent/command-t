" Vimball Archiver by Charles E. Campbell, Jr., Ph.D.
UseVimball
finish
ruby/command-t/base.rb	[[[1
45
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  class Base
    def initialize path = Dir.pwd, options = {}
      @scanner = Scanner.scanner path, options
      @matcher = Matcher.new @scanner, options
    end

    # Options:
    #   :limit (integer): limit the number of returned matches
    def sorted_matches_for str, options = {}
      @matcher.sorted_matches_for str, options
    end

    def flush
      @scanner.flush
    end

    def path= path
      @scanner.path = path
    end
  end # class Base
end # CommandT
ruby/command-t/controller.rb	[[[1
209
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  class Controller
    def initialize
      @prompt = Prompt.new
      @scanner = CommandT::Base.new nil,
        :max_files              => get_number('g:CommandTMaxFiles'),
        :max_depth              => get_number('g:CommandTMaxDepth'),
        :always_show_dot_files  => get_bool('g:CommandTAlwaysShowDotFiles'),
        :never_show_dot_files   => get_bool('g:CommandTNeverShowDotFiles'),
        :scan_dot_directories   => get_bool('g:CommandTScanDotDirectories')
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

    def accept_selection options = {}
      selection = @match_window.selection
      hide
      open_selection(selection, options) unless selection.nil?
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

    def get_number name
      return nil if VIM::evaluate("exists(\"#{name}\")").to_i == 0
      VIM::evaluate("#{name}").to_i
    end

    def get_bool name
      return nil if VIM::evaluate("exists(\"#{name}\")").to_i == 0
      VIM::evaluate("#{name}").to_i != 0
    end

    # Backslash-escape space, \, |, %, #, "
    def sanitize_path_string str
      # for details on escaping command-line mode arguments see: :h :
      # (that is, help on ":") in the Vim documentation.
      str.gsub(/[ \\|%#"]/, '\\\\\0')
    end

    def open_selection selection, options = {}
      command = options[:command] || 'e'
      selection = sanitize_path_string selection
      VIM::command "silent #{command} #{selection}"
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
      map '<C-CR>',   'AcceptSelectionSplit'
      map '<C-s>',    'AcceptSelectionSplit'
      map '<C-t>',    'AcceptSelectionTab'
      map '<C-v>',    'AcceptSelectionVSplit'
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
ruby/command-t/extconf.rb	[[[1
32
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'mkmf'

def missing item
  puts "couldn't find #{item} (required)"
  exit 1
end

have_header('ruby.h') or missing('ruby.h')
create_makefile('ext')
ruby/command-t/match_window.rb	[[[1
321
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'ostruct'

module CommandT
  class MatchWindow
    @@selection_marker  = '> '
    @@marker_length     = @@selection_marker.length
    @@unselected_marker = ' ' * @@marker_length

    def initialize options = {}
      @prompt = options[:prompt]

      # save existing window dimensions so we can restore them later
      @windows = []
      (0..(VIM::Window.count - 1)).each do |i|
        window = OpenStruct.new :index => i, :height => VIM::Window[i].height
        @windows << window
      end

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
      VIM::set_option 'noequalalways'   # don't auto-balance window sizes

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
      restore_window_dimensions
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
      @matches.each_with_index do |match, idx|
        if match[0, @find_string.length].casecmp(@find_string) == 0
          old_selection = @selection
          @selection = idx
          print_match(old_selection)  # redraw old selection (removes marker)
          print_match(@selection)     # redraw new selection (adds marker)
          break
        end
      end
    end

    # Returns the currently selected item as a String.
    def selection
      @matches[@selection]
    end

  private

    def restore_window_dimensions
      # sort from tallest to shortest
      @windows.sort! { |a, b| b.height <=> a.height }

      # starting with the tallest ensures that there are no constraints
      # preventing windows on the side of vertical splits from regaining
      # their original full size
      @windows.each do |w|
        VIM::Window[w.index].height = w.height
      end
    end

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
      return unless @window.select
      unlock
      @buffer[idx + 1] = match_text_for_idx idx
      lock
    end

    # Print all matches.
    def print_matches
      return unless @window.select
      unlock
      clear
      match_count = @matches.length
      actual_lines = 1
      @window_width = @window.width # update cached value
      if match_count == 0
        @window.height = actual_lines
        @buffer[1] = '-- NO MATCHES --'
      else
        max_lines = VIM::Screen.lines - 5
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
end
ruby/command-t/prompt.rb	[[[1
165
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

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
end # module CommandT
ruby/command-t/scanner/base.rb	[[[1
40
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  module Scanner
    # Common methods to be inherited by concrete subclasses.
    class Base
      def flush
        @paths = nil
      end

      def path= str
        if @path != str
          @path = str
          flush
        end
      end
    end # class AbstractScanner
  end # module Scanner
end # module CommandT
ruby/command-t/scanner/find.rb	[[[1
48
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  module Scanner
    # Simplistic scanner that wraps 'find . -type f'.
    class Find < Base
      def initialize path = Dir.pwd, options = {}
        @path = path
        @max_depth = 15
        @max_depth = options[:max_depth].to_i unless options[:max_depth].nil?
      end

      def paths
        return @paths unless @paths.nil?
        begin
          pwd = Dir.pwd
          Dir.chdir @path
          @paths = `find . -type f -maxdepth #{@max_depth} 2> /dev/null`.
            split("\n").map { |path| path[2..-1] }
        ensure
          Dir.chdir pwd
        end
        @paths
      end
    end # class Find
  end # module Scanner
end # module CommandT
ruby/command-t/scanner/ruby.rb	[[[1
76
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  module Scanner
    class Ruby < Base
      class DepthLimitExceeded < ::RuntimeError; end
      class FileLimitExceeded < ::RuntimeError; end

      def initialize path = Dir.pwd, options = {}
        @path                 = path
        @max_depth            = options[:max_depth] || 15
        @max_files            = options[:max_files] || 10_000
        @scan_dot_directories = options[:scan_dot_directories] || false
        @exclude              = options[:excludes] || /\A(\.git)\z/
      end

      def paths
        return @paths unless @paths.nil?
        begin
          @paths = []
          @depth = 0
          @files = 0
          @prefix_len = @path.length
          add_paths_for_directory @path, @paths
        rescue FileLimitExceeded, DepthLimitExceeded
        end
        @paths
      end

    private

      def add_paths_for_directory dir, accumulator
        Dir.foreach(dir) do |entry|
          next if ['.', '..'].include?(entry)
          path = File.join(dir, entry)
          unless entry.match(@exclude)
            if File.file?(path)
              @files += 1
              raise FileLimitExceeded if @files > @max_files
              accumulator << path[@prefix_len + 1..-1]
            elsif File.directory?(path)
              next if (entry.match(/\A\./) && !@scan_dot_directories)
              @depth += 1
              raise DepthLimitExceeded if @depth > @max_depth
              add_paths_for_directory path, accumulator
              @depth -= 1
            end
          end
        end
      rescue Errno::EACCES
        # skip over directories for which we don't have access
      end
    end # class Ruby
  end # module Scanner
end # module CommandT
ruby/command-t/scanner.rb	[[[1
35
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  # Reads the current directory recursively for the paths to all regular files.
  module Scanner
    autoload :Base, 'command-t/scanner/base'
    autoload :Find, 'command-t/scanner/find'
    autoload :Ruby, 'command-t/scanner/ruby'

    def self.scanner path = nil, options = {}
      Ruby.new path, options
    end
  end # module Scanner
end # module CommandT
ruby/command-t/settings.rb	[[[1
73
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  # Convenience class for saving and restoring global settings.
  class Settings
    def save
      @timeoutlen     = get_number 'timeoutlen'
      @report         = get_number 'report'
      @sidescroll     = get_number 'sidescroll'
      @sidescrolloff  = get_number 'sidescrolloff'
      @equalalways    = get_bool 'equalalways'
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
      set_bool 'equalalways', @equalalways
      set_bool 'hlsearch', @hlsearch
      set_bool 'insertmode', @insertmode
      set_bool 'showcmd', @showcmd
      set_bool 'list', @list
    end

  private

    def get_number setting
      VIM::evaluate("&#{setting}").to_i
    end

    def get_bool setting
      VIM::evaluate("&#{setting}").to_i == 1
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
  end # class Settings
end # module CommandT
ruby/command-t/stub.rb	[[[1
46
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  class Stub
    @@load_error = ['command-t.vim could not load the necessary modules',
                    'Please double-check the installation instructions',
                    'For more information type:  :help command-t']

    def show
      warn *@@load_error
    end

    def flush
      warn *@@load_error
    end

  private

    def warn *msg
      VIM::command 'echohl WarningMsg'
      msg.each { |m| VIM::command "echo '#{m}'" }
      VIM::command 'echohl none'
    end
  end # class Stub
end # module CommandT
ruby/command-t.rb	[[[1
39
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  # C extension
  autoload :Match,        'command-t/ext'
  autoload :Matcher,      'command-t/ext'

  # low-level modules (independent specs)
  autoload :Base,         'command-t/base'
  autoload :Scanner,      'command-t/scanner'

  # high-level modules (VIM integration)
  autoload :Controller,   'command-t/controller'
  autoload :MatchWindow,  'command-t/match_window'
  autoload :Prompt,       'command-t/prompt'
  autoload :Settings,     'command-t/settings'
  autoload :Stub,         'command-t/stub'
end # module CommandT
ruby/vim/screen.rb	[[[1
34
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module VIM
  module Screen
    def self.lines
      VIM.evaluate('&lines').to_i
    end

    def self.columns
      VIM.evaluate('&columns').to_i
    end
  end # module Screen
end # module VIM
ruby/vim/window.rb	[[[1
40
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

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
end # module VIM
ruby/vim.rb	[[[1
41
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'vim/screen'
require 'vim/window'

module VIM
  def self.has_syntax?
    VIM.evaluate('has("syntax")').to_i != 0
  end

  def self.pwd
    VIM.evaluate('getcwd()')
  end

  # Escape a string for safe inclusion in a Vim single-quoted string
  # (single quotes escaped by doubling, everything else is literal)
  def self.escape_for_single_quotes str
    str.gsub "'", "''"
  end
end # module VIM
ruby/command-t/ext.c	[[[1
69
// Copyright 2010 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include "match.h"
#include "matcher.h"

VALUE mCommandT         = 0; // module CommandT
VALUE cCommandTMatch    = 0; // class CommandT::Match
VALUE cCommandTMatcher  = 0; // class CommandT::Matcher

VALUE CommandT_option_from_hash(const char *option, VALUE hash)
{
    if (NIL_P(hash))
        return Qnil;
    if (TYPE(hash) != T_HASH)
        rb_raise(rb_eArgError, "options not a hash");

    VALUE key = ID2SYM(rb_intern(option));
    if (rb_funcall(hash, rb_intern("has_key?"), 1, key) == Qtrue)
        return rb_hash_aref(hash, key);
    else
        return Qnil;
}

void Init_ext()
{
    // module CommandT
    mCommandT = rb_define_module("CommandT");

    // class CommandT::Match
    cCommandTMatch = rb_define_class_under(mCommandT, "Match", rb_cObject);

    // methods
    rb_define_method(cCommandTMatch, "initialize", CommandTMatch_initialize, -1);
    rb_define_method(cCommandTMatch, "matches?", CommandTMatch_matches, 0);
    rb_define_method(cCommandTMatch, "score", CommandTMatch_score, 0);
    rb_define_method(cCommandTMatch, "to_s", CommandTMatch_to_s, 0);

    // attributes
    rb_define_attr(cCommandTMatch, "offsets", Qtrue, Qfalse); // reader = true, writer = false

    // class CommandT::Matcher
    cCommandTMatcher = rb_define_class_under(mCommandT, "Matcher", rb_cObject);

    // methods
    rb_define_method(cCommandTMatcher, "initialize", CommandTMatcher_initialize, -1);
    rb_define_method(cCommandTMatcher, "sorted_matches_for", CommandTMatcher_sorted_matchers_for, 2);
    rb_define_method(cCommandTMatcher, "matches_for", CommandTMatcher_matches_for, 1);
}
ruby/command-t/match.c	[[[1
228
// Copyright 2010 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include "match.h"
#include "ext.h"

// Match.new abbrev, string, options = {}
VALUE CommandTMatch_initialize(int argc, VALUE *argv, VALUE self)
{
    // process arguments: 2 mandatory, 1 optional
    VALUE str, abbrev, options;
    if (rb_scan_args(argc, argv, "21", &str, &abbrev, &options) == 2)
        options = Qnil;
    str                     = StringValue(str);
    char *str_p             = RSTRING_PTR(str);
    long str_len            = RSTRING_LEN(str);
    abbrev                  = StringValue(abbrev);
    char *abbrev_p          = RSTRING_PTR(abbrev);
    long abbrev_len         = RSTRING_LEN(abbrev);

    // check optional options hash for overrides
    VALUE always_show_dot_files = CommandT_option_from_hash("always_show_dot_files", options);
    VALUE never_show_dot_files = CommandT_option_from_hash("never_show_dot_files", options);

    long cursor             = 0;
    int dot_file            = 0; // true if path is a dot-file
    int dot_search          = 0; // true if abbrev definitely matches a dot-file
    int pending_dot_search  = 0; // true if abbrev might match a dot-file

    rb_iv_set(self, "@str", str);
    VALUE offsets = rb_ary_new();

    // special case for zero-length search string: filter out dot-files
    if (abbrev_len == 0 && always_show_dot_files != Qtrue)
    {
        for (long i = 0; i < str_len; i++)
        {
            char c = str_p[i];
            if (c == '.')
            {
                if (i == 0 || str_p[i - 1] == '/')
                {
                    dot_file = 1;
                    break;
                }
            }
        }
    }

    for (long i = 0; i < abbrev_len; i++)
    {
        char c = abbrev_p[i];
        if (c >= 'A' && c <= 'Z')
            c += ('a' - 'A'); // add 32 to make lowercase
        else if (c == '.')
            pending_dot_search = 1;

        VALUE found = Qfalse;
        for (long j = cursor; j < str_len; j++, cursor++)
        {
            char d = str_p[j];
            if (d == '.')
            {
                if (j == 0)
                {
                    dot_file = 1; // initial dot
                    if (pending_dot_search)
                        dot_search = 1; // this is a dot-search in progress
                }
                else if (str_p[j - 1] == '/')
                {
                    dot_file = 1; // dot after path separator
                    if (pending_dot_search)
                        dot_search = 1; // this is a dot-search in progress
                }
            }
            else if (d >= 'A' && d <= 'Z')
                d += 'a' - 'A'; // add 32 to make lowercase
            if (c == d)
            {
                if (c != '.')
                    pending_dot_search = 0;
                rb_ary_push(offsets, LONG2FIX(cursor));
                cursor++;
                found = Qtrue;
                break;
            }
        }

        if (found == Qfalse)
        {
            offsets = Qnil;
            break;
        }
    }

    if (dot_file)
    {
        if (never_show_dot_files == Qtrue ||
            (!dot_search && always_show_dot_files != Qtrue))
            offsets = Qnil;
    }
    rb_iv_set(self, "@offsets", offsets);
    return Qnil;
}

VALUE CommandTMatch_matches(VALUE self)
{
    VALUE offsets = rb_iv_get(self, "@offsets");
    return NIL_P(offsets) ? Qfalse : Qtrue;
}

// Return a normalized score ranging from 0.0 to 1.0 indicating the
// relevance of the match. The algorithm is specialized to provide
// intuitive scores specifically for filesystem paths.
//
// 0.0 means the search string didn't match at all.
//
// 1.0 means the search string is a perfect (letter-for-letter) match.
//
// Scores will tend closer to 1.0 as:
//
//   - the number of matched characters increases
//   - matched characters appear closer to previously matched characters
//   - matched characters appear immediately after special "boundary"
//     characters such as "/", "_", "-", "." and " "
//   - matched characters are uppercase letters immediately after
//     lowercase letters of numbers
//   - matched characters are lowercase letters immediately after
//     numbers
VALUE CommandTMatch_score(VALUE self)
{
    // return previously calculated score if available
    VALUE score = rb_iv_get(self, "@score");
    if (!NIL_P(score))
        return score;

    // nil or empty offsets array means a score of 0.0
    VALUE offsets = rb_iv_get(self, "@offsets");
    if (NIL_P(offsets) || RARRAY(offsets)->len == 0)
    {
        score = rb_float_new(0.0);
        rb_iv_set(self, "@score", score);
        return score;
    }

    // if search string is equal to actual string score is 1.0
    VALUE str = rb_iv_get(self, "@str");
    if (RARRAY(offsets)->len == RSTRING(str)->len)
    {
        score = rb_float_new(1.0);
        rb_iv_set(self, "@score", score);
        return score;
    }

    double score_d = 0.0;
    double max_score_per_char = 1.0 / RARRAY(offsets)->len;
    for (long i = 0, max = RARRAY(offsets)->len; i < max; i++)
    {
        double score_for_char = max_score_per_char;
        long offset = FIX2LONG(RARRAY(offsets)->ptr[i]);
        if (offset > 0)
        {
            double factor   = 0.0;
            char curr       = RSTRING(str)->ptr[offset];
            char last       = RSTRING(str)->ptr[offset - 1];

            // look at previous character to see if it is "special"
            // NOTE: possible improvements here:
            // - number after another number should be 1.0, not 0.8
            // - need to think about sequences like "9-"
            if (last == '/')
                factor = 0.9;
            else if (last == '-' ||
                     last == '_' ||
                     last == ' ' ||
                     (last >= '0' && last <= '9'))
                factor = 0.8;
            else if (last == '.')
                factor = 0.7;
            else if (last >= 'a' && last <= 'z' &&
                     curr >= 'A' && curr <= 'Z')
                factor = 0.8;
            else
            {
                // if no "special" chars behind char, factor diminishes
                // as distance from last matched char increases
                if (i > 1)
                {
                    long distance = offset - FIX2LONG(RARRAY(offsets)->ptr[i - 1]);
                    factor = 1.0 / distance;
                }
                else
                    factor = 1.0 / (offset + 1);
            }
            score_for_char *= factor;
        }
        score_d += score_for_char;
    }
    score = rb_float_new(score_d);
    rb_iv_set(self, "@score", score);
    return score;
}

VALUE CommandTMatch_to_s(VALUE self)
{
    return rb_iv_get(self, "@str");
}
ruby/command-t/matcher.c	[[[1
154
// Copyright 2010 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <stdlib.h> /* for qsort() */
#include <string.h> /* for strcmp() */
#include "matcher.h"
#include "ext.h"

// comparison function for use with qsort
int comp(const void *a, const void *b)
{
    VALUE a_val = *(VALUE *)a;
    VALUE b_val = *(VALUE *)b;
    ID score = rb_intern("score");
    ID to_s = rb_intern("to_s");
    double a_score = RFLOAT(rb_funcall(a_val, score, 0))->value;
    double b_score = RFLOAT(rb_funcall(b_val, score, 0))->value;
    if (a_score > b_score)
        return -1; // a scores higher, a should appear sooner
    else if (a_score < b_score)
        return 1;  // b scores higher, a should appear later
    else
    {
        // fall back to alphabetical ordering
        VALUE a_str = rb_funcall(a_val, to_s, 0);
        VALUE b_str = rb_funcall(b_val, to_s, 0);
        char *a_p = RSTRING(a_str)->ptr;
        long a_len = RSTRING(a_str)->len;
        char *b_p = RSTRING(b_str)->ptr;
        long b_len = RSTRING(b_str)->len;
        int order = 0;
        if (a_len > b_len)
        {
            order = strncmp(a_p, b_p, b_len);
            if (order == 0)
                order = 1; // shorter string (b) wins
        }
        else if (a_len < b_len)
        {
            order = strncmp(a_p, b_p, a_len);
            if (order == 0)
                order = -1; // shorter string (a) wins
        }
        else
            order = strncmp(a_p, b_p, a_len);
        return order;
    }
}

VALUE CommandTMatcher_initialize(int argc, VALUE *argv, VALUE self)
{
    // process arguments: 1 mandatory, 1 optional
    VALUE scanner, options;
    if (rb_scan_args(argc, argv, "11", &scanner, &options) == 1)
        options = Qnil;
    if (NIL_P(scanner))
        rb_raise(rb_eArgError, "nil scanner");
    rb_iv_set(self, "@scanner", scanner);

    // check optional options hash for overrides
    VALUE always_show_dot_files = CommandT_option_from_hash("always_show_dot_files", options);
    if (always_show_dot_files != Qtrue)
        always_show_dot_files = Qfalse;
    VALUE never_show_dot_files = CommandT_option_from_hash("never_show_dot_files", options);
    if (never_show_dot_files != Qtrue)
        never_show_dot_files = Qfalse;
    rb_iv_set(self, "@always_show_dot_files", always_show_dot_files);
    rb_iv_set(self, "@never_show_dot_files", never_show_dot_files);
    return Qnil;
}

VALUE CommandTMatcher_sorted_matchers_for(VALUE self, VALUE abbrev, VALUE options)
{
    // process optional options hash
    VALUE limit_option = CommandT_option_from_hash("limit", options);

    // get matches in default (alphabetical) ordering
    VALUE matches = CommandTMatcher_matches_for(self, abbrev);

    abbrev = StringValue(abbrev);
    if (RSTRING(abbrev)->len == 1 && RSTRING(abbrev)->ptr[0] == '.')
        ; // maintain alphabetic order if search string is only "."
    else if (RSTRING(abbrev)->len > 0)
        // we have a non-empty search string, so sort by score
        qsort(RARRAY(matches)->ptr, RARRAY(matches)->len, sizeof(VALUE), comp);

    // apply optional limit option
    long limit = NIL_P(limit_option) ? 0 : NUM2LONG(limit_option);
    if (limit == 0 || RARRAY(matches)->len < limit)
        limit = RARRAY(matches)->len;

    // will return an array of strings, not an array of Match objects
    for (long i = 0; i < limit; i++)
    {
        VALUE str = rb_funcall(RARRAY(matches)->ptr[i], rb_intern("to_s"), 0);
        RARRAY(matches)->ptr[i] = str;
    }

    // trim off any items beyond the limit
    if (limit < RARRAY(matches)->len)
        (void)rb_funcall(matches, rb_intern("slice!"), 2, LONG2NUM(limit),
            LONG2NUM(RARRAY(matches)->len - limit));
    return matches;
}

VALUE CommandTMatcher_matches_for(VALUE self, VALUE abbrev)
{
    if (NIL_P(abbrev))
        rb_raise(rb_eArgError, "nil abbrev");
    VALUE matches = rb_ary_new();
    VALUE scanner = rb_iv_get(self, "@scanner");
    VALUE always_show_dot_files = rb_iv_get(self, "@always_show_dot_files");
    VALUE never_show_dot_files = rb_iv_get(self, "@never_show_dot_files");
    VALUE options = Qnil;
    if (always_show_dot_files == Qtrue)
    {
        options = rb_hash_new();
        rb_hash_aset(options, ID2SYM(rb_intern("always_show_dot_files")), always_show_dot_files);
    }
    else if (never_show_dot_files == Qtrue)
    {
        options = rb_hash_new();
        rb_hash_aset(options, ID2SYM(rb_intern("never_show_dot_files")), never_show_dot_files);
    }
    VALUE paths = rb_funcall(scanner, rb_intern("paths"), 0);
    for (long i = 0, max = RARRAY(paths)->len; i < max; i++)
    {
        VALUE path = RARRAY(paths)->ptr[i];
        VALUE match = rb_funcall(cCommandTMatch, rb_intern("new"), 3, path, abbrev, options);
        if (rb_funcall(match, rb_intern("matches?"), 0) == Qtrue)
            rb_funcall(matches, rb_intern("push"), 1, match);
    }
    return matches;
}
ruby/command-t/ext.h	[[[1
33
// Copyright 2010 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <ruby.h>

extern VALUE mCommandT;         // module CommandT
extern VALUE cCommandTMatch;    // class CommandT::Match
extern VALUE cCommandTMatcher;  // class CommandT::Matcher

// Encapsulates common pattern of checking for an option in an optional
// options hash. The hash itself may be nil, but an exception will be
// raised if it is not nil and not a hash.
VALUE CommandT_option_from_hash(const char *option, VALUE hash);
ruby/command-t/match.h	[[[1
29
// Copyright 2010 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <ruby.h>

extern VALUE CommandTMatch_initialize(int argc, VALUE *argv, VALUE self);
extern VALUE CommandTMatch_matches(VALUE self);
extern VALUE CommandTMatch_score(VALUE self);
extern VALUE CommandTMatch_to_s(VALUE self);
ruby/command-t/matcher.h	[[[1
30
// Copyright 2010 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <ruby.h>

extern VALUE CommandTMatcher_initialize(int argc, VALUE *argv, VALUE self);
extern VALUE CommandTMatcher_sorted_matchers_for(VALUE self, VALUE abbrev, VALUE options);

// most likely the function will be subsumed by the sorted_matcher_for function
extern VALUE CommandTMatcher_matches_for(VALUE self, VALUE abbrev);
ruby/command-t/depend	[[[1
24
# Copyright 2010 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

CFLAGS += -std=gnu99 -Wall -Wextra -Wno-unused-parameter
doc/command-t.txt	[[[1
332
*command-t.txt* Command-T plug-in for VIM

CONTENTS                                        *command-t-contents*

 1. Introduction            |command-t|
 2. Requirments             |command-t-requirements|
 3. Installation            |command-t-installation|
 4. Usage                   |command-t-usage|
 5. Commands                |command-t-commands|
 6. Mappings                |command-t-mappings|
 7. Options                 |command-t-options|
 8. Author                  |command-t-author|
 9. Website                 |command-t-website|
10. License                 |command-t-license|
11. History                 |command-t-history|


INTRODUCTION                                    *command-t*

The Command-T plug-in provides an extremely fast, intuitive mechanism for
opening files with a minimal number of keystrokes. It's named "Command-T"
because it is inspired by the "Go to File" window bound to Command-T in
TextMate.

Files are selected by typing characters that appear in their paths, and are
ordered by an algorithm which knows that characters that appear in certain
locations (for example, immediately after a path separator) should be given
more weight.

A preview screencast introducing the plug-in can be viewed at:

  https://wincent.com/blog/bringing-textmate-style-command-t-to-vim


REQUIREMENTS                                    *command-t-requirements*

1. VIM compiled with Ruby support

Command-T requires VIM to be compiled with Ruby support. (MacVim, for example,
comes with Ruby support while the command-line version of Vim shipped with Mac
OS X Snow Leopard does not.)

You can check for Ruby support by launching VIM with the --version switch:

  vim --version

If "+ruby" appears in the version information then your version of VIM has
Ruby support.

Another way to check is to simply try using the :ruby command from within VIM
itself:

  :ruby 1

If your VIM lacks support you'll see an error message like this:

  E319: Sorry, the command is not available in this version

2. Ruby 1.8.7 or later

The plug-in is developed and tested using Ruby 1.8.7, and makes use of at
least one method which is not present in Ruby 1.8.6 (String#each_char). Rather
than target multiple versions which I cannot properly test, I prefer to
support one known, tested version.

3. C compiler

Part of Command-T is implemented in C as a Ruby extension for speed, allowing
it to work responsively even on directory hierarchies containing enormous
numbers of files. As such, a C compiler is required in order to build the
extension and complete the installation.


INSTALLATION                                    *command-t-installation*

Command-T is distributed as a "vimball" which means that it can be installed
by opening it in VIM and then sourcing it:

  :e command-t.vba
  :so %

The files will be installed in your |'runtimepath'|. To check where this is
you can issue:

  :echo &rtp

The C extension must then be built, which can be done from the shell. If you
use a typical |'runtimepath'| then the files were installed inside ~/.vim and
you can build the extension with:

  cd ~/.vim/ruby/command-t
  ruby extconf.rb
  make


USAGE                                           *command-t-usage*

Bring up the Command-T match window by typing:

  <Leader>t

If a mapping for <Leader>t already exists at the time the plug-in is loaded
then Command-T will not overwrite it. You can instead open the match window by
issuing the command:

  :CommandT

A prompt will appear at the bottom of the screen along with a match window
showing all of the files in the current directory (as returned by the
|:pwd| command).

Type letters in the prompt to narrow down the selection, showing only the
files whose paths contain those letters in the specified order. Letters do not
need to appear consecutively in a path in order for it to be classified as a
match.

Once you the desired file has been selected it can be opened by pressing <CR>.

The following mappings are active when the prompt has focus:

    <BS>        delete the character to the left of the cursor
    <Del>       delete the cursor at the cursor
    <Left>      move the cursor one character to the left
    <C-h>       move the cursor one character to the left
    <Right>     move the cursor one character to the right
    <C-l>       move the cursor one character to the right
    <C-a>       move the cursor to the start (left)
    <C-e>       move the cursor to the end (right)
    <C-u>       clear the contents of the prompt
    <Tab>       change focus to the match listing

The following mappings are active when either the prompt or the match listing
has focus:

    <CR>        open the selected file
    <C-CR>      open the selected file in a new split window
    <C-s>       open the selected file in a new split window
    <C-v>       open the selected file in a new vertical split window
    <C-t>       open the selected file in a new tab
    <C-j>       select next file in the match listing
    <C-n>       select next file in the match listing
    <Down>      select next file in the match listing
    <C-k>       select previous file in the match listing
    <C-p>       select previous file in the match listing
    <Up>        select previous file in the match listing
    <Esc>       cancel (dismisses match listing)
    <C-c>       cancel (dismisses match listing)

The following mappings are active when the match listing has focus:

    <Tab>       change focus to the prompt

In addition, when the match listing has focus, typing a character will cause
the selection to jump to the first path which begins with that character.
Typing multiple characters consecutively can be used to distinguish between
paths which begin with the same prefix.


COMMANDS                                        *command-t-commands*

                                                *CommandT*
|:CommandT|     brings up the Command-T match window, starting in the
                current working directory as returned by the|:pwd|
                command.

                                                *CommandTFlush*
                                                *command-t-flush*
|:CommandTFlush|instructs the plug-in to flush its path cache, causing
                the directory to be rescanned for new or deleted paths
                the next time the match window is shown


MAPPINGS                                        *command-t-mappings*

By default Command-T comes with only one mapping:

  <Leader>t     bring up the Command-T match window

However, Command-T won't overwrite a pre-existing mapping so if you prefer
to define a different mapping use a line like this in your ~/.vimrc:

  nmap <silent> <Leader>t :CommandT<CR>

Replacing "<Leader>t" with your mapping of choice.

Note that in the case of MacVim you actually can map to Command-T (written
as <D-t> in VIM) in your ~/.gvimrc file if you first unmap the existing menu
binding of Command-T to "New Tab":

  if has("gui_macvim")
    macmenu &File.New\ Tab key=<nop>
    map <D-t> :CommandT<CR>
  endif


OPTIONS                                         *command-t-options*

A number of options may be set in your ~/.vimrc to influence the behaviour of
the plug-in. To set an option, you include a line like this in your ~/.vimrc:

    let g:CommandTMaxFiles=20000

Following is a list of all available options:

                                                *command-t-max-files*
  |g:CommandTMaxFiles|                           number (default 10000)

      The maximum number of files that will be considered when scanning the
      current directory. Upon reaching this number scanning stops.

                                                *command-t-max-depth*
  |g:CommandTMaxDepth|                           number (default 15)

      The maximum depth (levels of recursion) to be explored when scanning the
      current directory. Any directories at levels beyond this depth will be
      skipped.

                                                *command-t-always-show-dot-files*
  |g:CommandTAlwaysShowDotFiles|                 boolean (default: 0)

      By default Command-T will show dot-files only if the entered search
      string contains a dot that could cause a dot-file to match. When set to
      a non-zero value, this setting instructs Command-T to always include
      matching dot-files in the match list regardless of whether the search
      string contains a dot. See also |g:CommandTNeverShowDotFiles|.

                                                *command-t-never-show-dot-files*
  |g:CommandTNeverShowDotFiles|                  boolean (default: 0)

      By default Command-T will show dot-files if the entered search string
      contains a dot that could cause a dot-file to match. When set to a
      non-zero value, this setting instructs Command-T to never show dot-files
      under any circumstances. Note that it is contradictory to set both this
      setting and |g:CommandTAlwaysShowDotFiles| to true, and if you do so VIM
      will suffer from headaches, nervous twitches, and sudden mood swings.

                                                *command-t-scan-dot-directories*
  |g:CommandTScanDotDirectories|                 boolean (default: 0)

      Normally Command-T will not recurse into "dot-directories" (directories
      whose names begin with a dot) while performing its initial scan. Set
      this setting to a non-zero value to override this behavior and recurse.
      Note that this setting is completely independent of the
      |g:CommandTAlwaysShowDotFiles| and |g:CommandTNeverShowDotFiles|
      settings; those apply only to the selection and display of matches
      (after scanning has been performed), whereas
      |g:CommandTScanDotDirectories| affects the behaviour at scan-time.

      Note also that even with this setting on you can still use Command-T to
      open files inside a "dot-directory" such as ~/.vim, but you have to use
      the |:cd| command to change into that directory first. For example:

        :cd ~/.vim
        :CommandT


AUTHOR                                          *command-t-author*

Command-T is written and maintained by Wincent Colaiuta <win@wincent.com>.

As this was the first VIM plug-in I had ever written I was heavily influenced
by the design of the LustyExplorer plug-in by Stephen Bach, which I understand
is one of the largest Ruby-based VIM plug-ins to date.

While the Command-T codebase doesn't contain any code directly copied from
LustyExplorer, I did use it as a reference for answers to basic questions (like
"How do you do 'X' in a Ruby-based VIM plug-in?"), and also copied some basic
architectural decisions (like the division of the code into Prompt, Settings
and MatchWindow classes).

LustyExplorer is available from:

  http://www.vim.org/scripts/script.php?script_id=1890


WEBSITE                                         *command-t-website*

The official website for Command-T is:

  https://wincent.com/products/command-t

The latest release will always be available from there.

Development in progress can be inspected via the project's Git repository
browser at:

  http://git.wincent.com/command-t.git

A copy of each release is also available from the official VIM scripts site
at:

  http://www.vim.org/scripts/

Bug reports should be submitted to the issue tracker at:

  https://wincent.com/issues


LICENSE                                         *command-t-license*

Copyright 2010 Wincent Colaiuta. All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.


HISTORY                                         *command-t-history*

0.1 (22 March 2010)

- initial public release

------------------------------------------------------------------------------
vim:tw=78:ft=help:
plugin/command-t.vim	[[[1
145
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

if exists("g:command_t_loaded")
  finish
endif
let g:command_t_loaded = 1

command CommandT :call <SID>CommandTShow()
command CommandTFlush :call <SID>CommandTFlush()

nmap <unique> <silent> <Leader>t :CommandT<CR>

function s:CommandTRubyWarning()
  echohl WarningMsg
  echo "command-t.vim requires Vim to be compiled with Ruby support"
  echo "For more information type:  :help command-t"
  echohl none
endfunction

function s:CommandTShow()
  if has('ruby')
    ruby $command_t.show
  else
    call s:CommandTRubyWarning()
  endif
endfunction

function s:CommandTFlush()
  if has('ruby')
    ruby $command_t.flush
  else
    call s:CommandTRubyWarning()
  endif
endfunction

if !has('ruby')
  finish
endif

function CommandTKeyPressed(arg)
  ruby $command_t.key_pressed
endfunction

function CommandTBackspacePressed()
  ruby $command_t.backspace_pressed
endfunction

function CommandTDeletePressed()
  ruby $command_t.delete_pressed
endfunction

function CommandTAcceptSelection()
  ruby $command_t.accept_selection
endfunction

function CommandTAcceptSelectionTab()
  ruby $command_t.accept_selection :command => 'tabe'
endfunction

function CommandTAcceptSelectionSplit()
  ruby $command_t.accept_selection :command => 'sp'
endfunction

function CommandTAcceptSelectionVSplit()
  ruby $command_t.accept_selection :command => 'vs'
endfunction

function CommandTToggleFocus()
  ruby $command_t.toggle_focus
endfunction

function CommandTCancel()
  ruby $command_t.cancel
endfunction

function CommandTSelectNext()
  ruby $command_t.select_next
endfunction

function CommandTSelectPrev()
  ruby $command_t.select_prev
endfunction

function CommandTClear()
  ruby $command_t.clear
endfunction

function CommandTCursorLeft()
  ruby $command_t.cursor_left
endfunction

function CommandTCursorRight()
  ruby $command_t.cursor_right
endfunction

function CommandTCursorEnd()
  ruby $command_t.cursor_end
endfunction

function CommandTCursorStart()
  ruby $command_t.cursor_start
endfunction

ruby << EOF
  # require Ruby files
  begin
    require 'vim'
    require 'command-t'
  rescue LoadError
    lib = "#{ENV['HOME']}/.vim/ruby"
    raise if $LOAD_PATH.include?(lib)
    $LOAD_PATH << lib
    retry
  end

  # prepare controller
  begin
    $command_t = CommandT::Controller.new
  rescue LoadError
    # most likely didn't build the C extension yet
    $command_t = CommandT::Stub.new
  end
EOF
