module CommandT
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

    def accept_selection options = {}
      selection = @match_window.selection
      hide
      open_selection selection, options
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
