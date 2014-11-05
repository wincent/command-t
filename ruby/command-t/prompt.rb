# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

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
      ::VIM::command 'echo'
      ::VIM::command 'redraw'
    end

    # Clear any entered text.
    def clear!
      @abbrev = ''
      @col    = 0
      redraw
    end

    # Remove word before cursor
    def clear_prev_word!
      suffix_length = @abbrev.length - @col
      @abbrev.match(
        %r{
          (.*?)                 # prefix
          \w*\s*                # word to clear
          (.{#{suffix_length}}) # suffix
          \z
        }x
      )
      @abbrev = $~[1] + $~[2]
      @col = @abbrev.length - suffix_length
      redraw
    end

    # Insert a character at (before) the current cursor position.
    def add!(char)
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

    def set_status(*args)
      # see ':help :echo' for why forcing a redraw here helps
      # prevent the status line from getting inadvertantly cleared
      # after our echo commands
      ::VIM::command 'redraw'
      while (highlight = args.shift) && (text = args.shift)
        text = VIM::escape_for_single_quotes text
        ::VIM::command "echohl #{highlight}"
        ::VIM::command "echon '#{text}'"
      end
      ::VIM::command 'echohl None'
    end
  end # class Prompt
end # module CommandT
