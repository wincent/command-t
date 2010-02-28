" command-t.vim
" Copyright 2010 Wincent Colaiuta
"
" Largely derived from from Stephen Bach's lusty-explorer.vim plugin
" (http://www.vim.org/scripts/script.php?script_id=1890):
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

if !has('ruby')
  finish
endif

function! CommandTKeyPressed(arg)
  ruby $command_t.key_pressed
endfunction

function! CommandTBackspacePressed()
  ruby $command_t.backspace_pressed
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
        return if selected?
        initial = $curwin
        while true do
          VIM::command 'wincmd w'     # cycle through windows
          break if $curwin == self    # have selected desired window
          break if $curwin == initial # have already looped through all windows
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

      # Erase whatever is displayed in the prompt line,
      # effectively disposing of the prompt
      def self.dispose
        VIM::command 'echo'
        VIM::command 'redraw'
      end

      def initialize
        @abbrev = '' # abbreviation entered so far
      end

      # Clear any entered text.
      def clear!
        @abbrev = ''
      end

      def add! char
        @abbrev += char
        redraw
      end

      def backspace!
        @abbrev.chop!
        redraw
      end

      def redraw
        set_status 'Comment', '>>',
          'None', ' ',
          'None', @abbrev,
          'Underlined', ' '
      end

    private

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
      def initialize
        # create match window and set it up
        [
          'silent! botright 1split GoToFile',
          'setlocal bufhidden=delete', # delete buf when no longer displayed
          'setlocal buftype=nofile', # buffer is not related to any file
          'setlocal nomodifiable',
          'setlocal noswapfile',
          'setlocal nowrap',
          'setlocal nonumber',
          'setlocal foldcolumn=0',
          'setlocal nocursorline',
          'setlocal nospell',
          'setlocal nobuflisted', # don't show up in the buffer list
          'setlocal textwidth=0'
        ].each { |command| VIM::command command }

        # sanity check: make sure the buffer really was created
        raise "Can't find buffer" unless $curbuf.name.match /GoToFile/

        # global settings (must manually save and restore)
        @settings = Settings.new
        @settings.save
        VIM::set_option 'timeoutlen=0'
        VIM::set_option 'noinsertmode'
        VIM::set_option 'noshowcmd'
        VIM::set_option 'nolist'
        VIM::set_option 'report=9999'
        VIM::set_option 'sidescroll=0'
        VIM::set_option 'sidescrolloff=0'

        # syntax coloring
        # VIM::command returns nil, so can't be used to capture highlight info
        #@cursor_highlight = VIM::command('highlight Cursor').sub(/\ACursor\s+xxx\s+/, '')

        @focus = :prompt
        @selection = nil
        @abbrev = ''
        @window = $curwin
        @buffer = $curbuf

        # sanity check
        #raise @buffer.name
        #raise "Can't find buffer" unless @buffer.name == 'GoToFile'
      end

      def close
        VIM::command "bwipeout! #{@buffer.number}"
        @settings.restore
        Prompt.dispose
      end

      def toggle_focus
        if @focus == :prompt
          focus_results
        else
          focus_prompt
        end
      end

      def add! char
        @abbrev += char
        relist
      end

      def backspace!
        @abbrev.chop!
        relist
      end

      private

      def clear
        # range = % (whole buffer)
        # action = d (delete)
        # register = _ (black hole register, don't record deleted text)
        VIM::command 'silent %d _'
      end

      def hide_cursor
        VIM::command 'highlight Cursor NONE'
      end

      def show_cursor
        #VIM::command "highlight Cursor #{@cursor_highlight}"
        VIM::command 'highlight Cursor guibg=fg guifg=bg'
      end

      def lock
        VIM::command 'setlocal nomodifiable'
      end

      def unlock
        VIM::command 'setlocal modifiable'
      end

      def relist
        # update path list for new abbreviation
      end

      def focus_results
        @focus = :results
      end

      def focus_prompt
        @focus = :prompt
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
        @settings = Settings.new
        @prompt = Prompt.new
      end

      def show
        @initial_window = $curwin
        @initial_buffer = $curbuf
        @settings.save
        create_match_window
        register_for_key_presses
        show_prompt
      end

      def hide
        @match_window.close
        @settings.restore
        @initial_window.select
        VIM::command "silent b #{@initial_buffer.number}"
      end

      def create_match_window
        @match_window = MatchWindow.new
      end

      def show_prompt
        @prompt.clear!
        @prompt.redraw
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
        map '<BS>',   'BackspacePressed'
        map '<CR>',   'AcceptSelection'
        # TODO: maps for opening in split windows, tabs etc
        map '<Tab>',  'ToggleFocus'
        map '<Esc>',  'Cancel'
        map '<C-c>',  'Cancel'
        map '<C-n>',  'SelectNext'
        map '<C-p>',  'SelectPrev'
        map '<Down>', 'SelectNext'
        map '<Up>',   'SelectPrev'
      end

      def key_pressed
        key = VIM::evaluate('a:arg').to_i.chr
        @prompt.add! key
      end

      def backspace_pressed
        @prompt.backspace!
      end

      def accept_selection
      end

      def toggle_focus
      end

      def cancel
        hide
      end

      def select_next
      end

      def select_prev
      end
    end # class Controller
  end # module commandT

  $command_t = CommandT::Controller.new
EOF
