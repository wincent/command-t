# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'ostruct'
require 'command-t/settings'

module CommandT
  class MatchWindow
    SELECTION_MARKER  = '> '
    MARKER_LENGTH     = SELECTION_MARKER.length
    UNSELECTED_MARKER = ' ' * MARKER_LENGTH
    MH_START          = '<commandt>'
    MH_END            = '</commandt>'
    @@buffer          = nil

    def initialize(options = {})
      @highlight_color = options[:highlight_color] || 'PmenuSel'
      @min_height      = options[:min_height]
      @prompt          = options[:prompt]
      @reverse_list    = options[:match_window_reverse]

      # save existing window dimensions so we can restore them later
      @windows = (0..(::VIM::Window.count - 1)).map do |i|
        OpenStruct.new(
          :index  => i,
          :height => ::VIM::Window[i].height,
          :width  => ::VIM::Window[i].width
        )
      end

      set 'timeout', true        # ensure mappings timeout
      set 'hlsearch', false      # don't highlight search strings
      set 'insertmode', false    # don't make Insert mode the default
      set 'showcmd', false       # don't show command info on last line
      set 'equalalways', false   # don't auto-balance window sizes
      set 'timeoutlen', 0        # respond immediately to mappings
      set 'report', 9999         # don't show "X lines changed" reports
      set 'scrolloff', 0         # don't scroll near buffer edges
      set 'sidescroll', 0        # don't sidescroll in jumps
      set 'sidescrolloff', 0     # don't sidescroll automatically
      set 'updatetime', options[:debounce_interval]

      # show match window
      split_location = options[:match_window_at_top] ? 'topleft' : 'botright'
      if @@buffer # still have buffer from last time
        ::VIM::command "silent! #{split_location} #{@@buffer.number}sbuffer"
        raise "Can't re-open GoToFile buffer" unless $curbuf.number == @@buffer.number
        $curwin.height = 1
      else        # creating match window for first time and set it up
        ::VIM::command "silent! #{split_location} 1split GoToFile"
        set 'bufhidden', 'unload' # unload buf when no longer displayed
        set 'buftype', 'nofile'   # buffer is not related to any file
        set 'modifiable', false   # prevent manual edits
        set 'swapfile', false     # don't create a swapfile
        set 'wrap', false         # don't soft-wrap
        set 'number', false       # don't show line numbers
        set 'list', false         # don't use List mode (visible tabs etc)
        set 'foldcolumn', 0       # don't show a fold column at side
        set 'foldlevel', 99       # don't fold anything
        set 'cursorline', false   # don't highlight line cursor is on
        set 'spell', false        # spell-checking off
        set 'buflisted', false    # don't show up in the buffer list
        set 'textwidth', 0        # don't hard-wrap (break long lines)

        # don't show the color column
        set 'colorcolumn', 0 if VIM::exists?('+colorcolumn')

        # don't show relative line numbers
        set 'relativenumber', false if VIM::exists?('+relativenumber')

        # sanity check: make sure the buffer really was created
        raise "Can't find GoToFile buffer" unless $curbuf.name.match /GoToFile\z/
        @@buffer = $curbuf
      end

      # syntax coloring
      if VIM::has?('syntax')
        ::VIM::command "syntax match CommandTSelection \"^#{SELECTION_MARKER}.\\+$\""
        ::VIM::command 'syntax match CommandTNoEntries "^-- NO MATCHES --$"'
        ::VIM::command 'syntax match CommandTNoEntries "^-- NO SUCH FILE OR DIRECTORY --$"'
        set 'synmaxcol', 9999

        if VIM::has?('conceal')
          set 'conceallevel', 2
          set 'concealcursor', 'nvic'
          ::VIM::command 'syntax region CommandTCharMatched ' \
                         "matchgroup=CommandTCharMatched start=+#{MH_START}+ " \
                         "matchgroup=CommandTCharMatchedEnd end=+#{MH_END}+ concealends"
          ::VIM::command 'highlight def CommandTCharMatched ' \
                         'term=bold,underline cterm=bold,underline ' \
                         'gui=bold,underline'
        end

        ::VIM::command "highlight link CommandTSelection #{@highlight_color}"
        ::VIM::command 'highlight link CommandTNoEntries Error'

        # hide cursor
        @cursor_highlight = get_cursor_highlight
        hide_cursor
      end

      # perform cleanup using an autocmd to ensure we don't get caught out
      # by some unexpected means of dismissing or leaving the Command-T window
      # (eg. <C-W q>, <C-W k> etc)
      ::VIM::command 'autocmd! * <buffer>'
      ::VIM::command 'autocmd BufLeave <buffer> silent! ruby $command_t.leave'
      ::VIM::command 'autocmd BufUnload <buffer> silent! ruby $command_t.unload'

      @has_focus  = false
      @abbrev     = ''
      @window     = $curwin
    end

    def close
      # Unlisted buffers like those provided by Netrw, NERDTree and Vim's help
      # don't actually appear in the buffer list; if they are the only such
      # buffers present when Command-T is invoked (for example, when invoked
      # immediately after starting Vim with a directory argument, like `vim .`)
      # then performing the normal clean-up will yield an "E90: Cannot unload
      # last buffer" error. We can work around that by doing a :quit first.
      if ::VIM::Buffer.count == 0
        ::VIM::command 'silent quit'
      end

      # Workaround for upstream bug in Vim 7.3 on some platforms
      #
      # On some platforms, $curbuf.number always returns 0. One workaround is
      # to build Vim with --disable-largefile, but as this is producing lots of
      # support requests, implement the following fallback to the buffer name
      # instead, at least until upstream gets fixed.
      #
      # For more details, see: https://wincent.com/issues/1617
      if $curbuf.number == 0
        # use bwipeout as bunload fails if passed the name of a hidden buffer
        ::VIM::command 'silent! bwipeout! GoToFile'
        @@buffer = nil
      else
        ::VIM::command "silent! bunload! #{@@buffer.number}"
      end
    end

    def leave
      close
      unload
    end

    def unload
      restore_window_dimensions
      @settings.restore
      @prompt.dispose
      show_cursor
    end

    def add!(char)
      @abbrev += char
    end

    def backspace!
      @abbrev.chop!
    end

    def select_next
      @reverse_list ? _prev : _next
    end

    def select_prev
      @reverse_list ? _next : _prev
    end

    def matches=(matches)
      if matches != @matches
        @matches = matches
        @selection = 0
        print_matches
        move_cursor_to_selected_line
      end
    end

    def focus
      unless @has_focus
        @has_focus = true
        if VIM::has?('syntax')
          ::VIM::command 'highlight link CommandTSelection Search'
        end
      end
    end

    def unfocus
      if @has_focus
        @has_focus = false
        if VIM::has?('syntax')
          ::VIM::command "highlight link CommandTSelection #{@highlight_color}"
        end
      end
    end

    def find(char)
      # is this a new search or the continuation of a previous one?
      now = Time.now
      if @last_key_time.nil? or @last_key_time < (now - 0.5)
        @find_string = char
      else
        @find_string += char
      end
      @last_key_time = now

      # see if there's anything up ahead that matches
      matches = @reverse_list ? @matches.reverse : @matches
      matches.each_with_index do |match, idx|
        if match[0, @find_string.length].casecmp(@find_string) == 0
          old_selection = @selection
          @selection = @reverse_list ? matches.length - idx - 1 : idx
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

    def print_no_such_file_or_directory
      print_error 'NO SUCH FILE OR DIRECTORY'
    end

  private

    def _next
      if @selection < [@window.height, @matches.length].min - 1
        @selection += 1
        print_match(@selection - 1) # redraw old selection (removes marker)
        print_match(@selection)     # redraw new selection (adds marker)
        move_cursor_to_selected_line
      end
    end

    def _prev
      if @selection > 0
        @selection -= 1
        print_match(@selection + 1) # redraw old selection (removes marker)
        print_match(@selection)     # redraw new selection (adds marker)
        move_cursor_to_selected_line
      end
    end

    # Translate from a 0-indexed match index to a 1-indexed Vim line number.
    # Also takes into account reversed listings.
    def line(match_index)
      @reverse_list ? @window.height - match_index : match_index + 1
    end

    def set(setting, value)
      @settings ||= Settings.new
      @settings.set(setting, value)
    end

    def move_cursor_to_selected_line
      # on some non-GUI terminals, the cursor doesn't hide properly
      # so we move the cursor to prevent it from blinking away in the
      # upper-left corner in a distracting fashion
      @window.cursor = [line(@selection), 0]
    end

    def print_error(msg)
      return unless VIM::Window.select(@window)
      unlock
      clear
      @window.height = [1, @min_height].min
      @@buffer[1] = "-- #{msg} --"
      lock
    end

    def restore_window_dimensions
      # sort from tallest to shortest, tie-breaking on window width
      @windows.sort! do |a, b|
        order = b.height <=> a.height
        if order.zero?
          b.width <=> a.width
        else
          order
        end
      end

      # starting with the tallest ensures that there are no constraints
      # preventing windows on the side of vertical splits from regaining
      # their original full size
      @windows.each do |w|
        # beware: window may be nil
        if window = ::VIM::Window[w.index]
          window.height = w.height
          window.width  = w.width
        end
      end
    end

    def match_text_for_idx(idx)
      match = truncated_match @matches[idx].to_s
      if idx == @selection
        prefix = SELECTION_MARKER
        suffix = padding_for_selected_match match
      else
        if VIM::has?('syntax') && VIM::has?('conceal')
          match = match_with_syntax_highlight match
        end
        prefix = UNSELECTED_MARKER
        suffix = ''
      end
      prefix + match + suffix
    end

    # Highlight matching characters within the matched string.
    #
    # Note that this is only approximate; it will highlight the first matching
    # instances within the string, which may not actually be the instances that
    # were used by the matching/scoring algorithm to determine the best score
    # for the match.
    #
    def match_with_syntax_highlight(match)
      highlight_chars = @prompt.abbrev.downcase.scan(/./mu)
      match.scan(/./mu).inject([]) do |output, char|
        if char.downcase == highlight_chars.first
          highlight_chars.shift
          output.concat [MH_START, char, MH_END]
        else
          output << char
        end
      end.join
    end

    # Print just the specified match.
    def print_match(idx)
      return unless VIM::Window.select(@window)
      unlock
      @@buffer[line(idx)] = match_text_for_idx idx
      lock
    end

    def max_lines
      [1, VIM::Screen.lines - 5].max
    end

    # Print all matches.
    def print_matches
      match_count = @matches.length
      if match_count == 0
        print_error 'NO MATCHES'
      else
        return unless VIM::Window.select(@window)
        unlock
        clear
        @window_width = @window.width # update cached value
        desired_lines = [match_count, @min_height].max
        desired_lines = [max_lines, desired_lines].min
        @window.height = desired_lines
        matches = []
        (0...@window.height).each do |idx|
          text = match_text_for_idx(idx)
          @reverse_list ? matches.unshift(text) : matches.push(text)
        end
        matches.each_with_index do |match, idx|
          if @@buffer.count > idx
            @@buffer[idx + 1] = match
          else
            @@buffer.append(idx, match)
          end
        end
        lock
      end
    end

    # Prepare padding for match text (trailing spaces) so that selection
    # highlighting extends all the way to the right edge of the window.
    def padding_for_selected_match(str)
      len = str.length
      if len >= @window_width - MARKER_LENGTH
        ''
      else
        ' ' * (@window_width - MARKER_LENGTH - len)
      end
    end

    # Convert "really/long/path" into "really...path" based on available
    # window width.
    def truncated_match(str)
      len = str.length
      available_width = @window_width - MARKER_LENGTH
      return str if len <= available_width
      left = (available_width / 2) - 1
      right = (available_width / 2) - 2 + (available_width % 2)
      str[0, left] + '...' + str[-right, right]
    end

    def clear
      # range = % (whole buffer)
      # action = d (delete)
      # register = _ (black hole register, don't record deleted text)
      ::VIM::command 'silent %d _'
    end

    def get_cursor_highlight
      # there are 3 possible formats to check for, each needing to be
      # transformed in a certain way in order to reapply the highlight:
      #   Cursor xxx guifg=bg guibg=fg      -> :hi! Cursor guifg=bg guibg=fg
      #   Cursor xxx links to SomethingElse -> :hi! link Cursor SomethingElse
      #   Cursor xxx cleared                -> :hi! clear Cursor
      highlight = VIM::capture 'silent! 0verbose highlight Cursor'

      if highlight =~ /^Cursor\s+xxx\s+links to (\w+)/
        "link Cursor #{$~[1]}"
      elsif highlight =~ /^Cursor\s+xxx\s+cleared/
        'clear Cursor'
      elsif highlight =~ /Cursor\s+xxx\s+(.+)/
        "Cursor #{$~[1]}"
      else # likely cause E411 Cursor highlight group not found
        nil
      end
    end

    def hide_cursor
      if @cursor_highlight
        ::VIM::command 'highlight Cursor NONE'
      end
    end

    def show_cursor
      if @cursor_highlight
        ::VIM::command "highlight #{@cursor_highlight}"
      end
    end

    def lock
      set 'modifiable', false
    end

    def unlock
      set 'modifiable', true
    end
  end
end
