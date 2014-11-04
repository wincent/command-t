# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/finder/buffer_finder'
require 'command-t/finder/jump_finder'
require 'command-t/finder/file_finder'
require 'command-t/finder/mru_buffer_finder'
require 'command-t/finder/tag_finder'
require 'command-t/match_window'
require 'command-t/prompt'
require 'command-t/vim/path_utilities'
require 'command-t/util'

module CommandT
  class Controller
    include VIM::PathUtilities

    def initialize
      @prompt = Prompt.new
    end

    def show_buffer_finder
      @path          = VIM::pwd
      @active_finder = buffer_finder
      show
    end

    def show_jump_finder
      @path          = VIM::pwd
      @active_finder = jump_finder
      show
    end

    def show_mru_finder
      @path          = VIM::pwd
      @active_finder = mru_finder
      show
    end

    def show_tag_finder
      @path          = VIM::pwd
      @active_finder = tag_finder
      show
    end

    def show_file_finder
      # optional parameter will be desired starting directory, or ""

      arg = ::VIM::evaluate('a:arg')
      if arg && arg.size > 0
        @path = File.expand_path(arg, VIM::pwd)
      else
        traverse = VIM::get_string('g:CommandTTraverseSCM') || 'file'
        case traverse
        when 'file'
          @path = nearest_ancestor(VIM::current_file_dir, scm_markers) || VIM::pwd
        when 'dir'
          @path = nearest_ancestor(VIM::pwd, scm_markers) || VIM::pwd
        else
          @path = VIM::pwd
        end
      end

      @active_finder    = file_finder
      file_finder.path  = @path
      show
    rescue Errno::ENOENT
      # probably a problem with the optional parameter
      @match_window.print_no_such_file_or_directory
    end

    def hide
      @match_window.leave
      if VIM::Window.select @initial_window
        if @initial_buffer.number == 0
          # upstream bug: buffer number misreported as 0
          # see: https://wincent.com/issues/1617
          ::VIM::command "silent b #{@initial_buffer.name}"
        else
          ::VIM::command "silent b #{@initial_buffer.number}"
        end
      end
    end

    # Take current matches and stick them in the quickfix window.
    def quickfix
      hide

      matches = @matches.map do |match|
        "{ 'filename': '#{VIM::escape_for_single_quotes match}' }"
      end.join(', ')

      ::VIM::command 'call setqflist([' + matches + '])'
      ::VIM::command 'cope'
    end

    def refresh
      return unless @active_finder && @active_finder.respond_to?(:flush)
      @active_finder.flush
      list_matches!
    end

    def flush
      @max_height   = nil
      @min_height   = nil
      @file_finder  = nil
      @tag_finder   = nil
    end

    def handle_key
      key = ::VIM::evaluate('a:arg').to_i.chr
      if @focus == @prompt
        @prompt.add! key
        @needs_update = true
      else
        @match_window.find key
      end
    end

    def backspace
      if @focus == @prompt
        @prompt.backspace!
        @needs_update = true
      end
    end

    def delete
      if @focus == @prompt
        @prompt.delete!
        @needs_update = true
      end
    end

    def accept_selection(options = {})
      selection = @match_window.selection
      hide
      open_selection(selection, options) unless selection.nil?
    end

    def toggle_focus
      @focus.unfocus # old focus
      @focus = @focus == @prompt ? @match_window : @prompt
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
      list_matches!
    end

    def clear_prev_word
      @prompt.clear_prev_word!
      list_matches!
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

    def leave
      @match_window.leave
    end

    def unload
      @match_window.unload
    end

    def list_matches(options = {})
      return unless @needs_update || options[:force]

      @matches = @active_finder.sorted_matches_for(
        @prompt.abbrev,
        :case_sensitive => case_sensitive?,
        :limit          => match_limit,
        :threads        => CommandT::Util.processor_count
      )
      @match_window.matches = @matches

      @needs_update = false
    end

    def tab_command
      VIM::get_string('g:CommandTAcceptSelectionTabCommand') || 'tabe'
    end

    def split_command
      VIM::get_string('g:CommandTAcceptSelectionSplitCommand') || 'sp'
    end

    def vsplit_command
      VIM::get_string('g:CommandTAcceptSelectionVSplitCommand') || 'vs'
    end

  private

    def scm_markers
      markers = VIM::get_string('g:CommandTSCMDirectories')
      markers = markers && markers.split(/\s*,\s*/)
      markers = %w[.git .hg .svn .bzr _darcs] unless markers && markers.length
      markers
    end

    def list_matches!
      list_matches(:force => true)
    end

    def show
      @initial_window   = $curwin
      @initial_buffer   = $curbuf
      @match_window     = MatchWindow.new \
        :highlight_color      => VIM::get_string('g:CommandTHighlightColor'),
        :match_window_at_top  => VIM::get_bool('g:CommandTMatchWindowAtTop'),
        :match_window_reverse => VIM::get_bool('g:CommandTMatchWindowReverse'),
        :min_height           => min_height,
        :debounce_interval    => VIM::get_number('g:CommandTInputDebounce') || 50,
        :prompt               => @prompt
      @focus            = @prompt
      @prompt.focus
      register_for_key_presses
      set_up_autocmds
      clear # clears prompt and lists matches
    end

    def max_height
      @max_height ||= VIM::get_number('g:CommandTMaxHeight') || 0
    end

    def min_height
      @min_height ||= begin
        min_height = VIM::get_number('g:CommandTMinHeight') || 0
        min_height = max_height if max_height != 0 && min_height > max_height
        min_height
      end
    end

    def case_sensitive?
      if @prompt.abbrev.match(/[A-Z]/)
        if VIM::exists?('g:CommandTSmartCase')
          smart_case = VIM::get_bool('g:CommandTSmartCase')
        else
          smart_case = VIM::get_bool('&smartcase')
        end

        if smart_case
          return true
        end
      end

      if VIM::exists?('g:CommandTIgnoreCase')
        return !VIM::get_bool('g:CommandTIgnoreCase')
      end

      false
    end

    # Backslash-escape space, \, |, %, #, "
    def sanitize_path_string(str)
      # for details on escaping command-line mode arguments see: :h :
      # (that is, help on ":") in the Vim documentation.
      str.gsub(/[ \\|%#"]/, '\\\\\0')
    end

    def current_buffer_visible_in_other_window
      count = (0...::VIM::Window.count).to_a.inject(0) do |acc, i|
        acc += 1 if ::VIM::Window[i].buffer.number == $curbuf.number
        acc
      end
      count > 1
    end

    def default_open_command
      if !VIM::get_bool('&modified') ||
        VIM::get_bool('&hidden') ||
        VIM::get_bool('&autowriteall') && !VIM::get_bool('&readonly') ||
        current_buffer_visible_in_other_window
        VIM::get_string('g:CommandTAcceptSelectionCommand') || 'e'
      else
        'sp'
      end
    end

    def ensure_appropriate_window_selection
      # normally we try to open the selection in the current window, but there
      # is one exception:
      #
      # - we don't touch any "unlisted" buffer with buftype "nofile" (such as
      #   NERDTree or MiniBufExplorer); this is to avoid things like the "Not
      #   enough room" error which occurs when trying to open in a split in a
      #   shallow (potentially 1-line) buffer like MiniBufExplorer is current
      #
      # Other "unlisted" buffers, such as those with buftype "help" are treated
      # normally.
      initial = $curwin
      while true do
        break unless ::VIM::evaluate('&buflisted').to_i == 0 &&
          ::VIM::evaluate('&buftype').to_s == 'nofile'
        ::VIM::command 'wincmd w'     # try next window
        break if $curwin == initial # have already tried all
      end
    end

    def open_selection(selection, options = {})
      command = options[:command] || default_open_command
      selection = File.expand_path selection, @path
      selection = relative_path_under_working_directory selection
      selection = sanitize_path_string selection
      selection = File.join('.', selection) if selection =~ /^\+/
      ensure_appropriate_window_selection

      @active_finder.open_selection command, selection, options
    end

    def map(key, function, param = nil)
      ::VIM::command "noremap <silent> <buffer> #{key} " \
        ":call CommandT#{function}(#{param})<CR>"
    end

    def term
      @term ||= ::VIM::evaluate('&term')
    end

    def register_for_key_presses
      # "normal" keys (interpreted literally)
      numbers     = ('0'..'9').to_a.join
      lowercase   = ('a'..'z').to_a.join
      uppercase   = lowercase.upcase
      punctuation = '<>`@#~!"$%&/()=+*-_.,;:?\\\'{}[] ' # and space
      (numbers + lowercase + uppercase + punctuation).each_byte do |b|
        map "<Char-#{b}>", 'HandleKey', b
      end

      # "special" keys (overridable by settings)
      {
        'AcceptSelection'       => '<CR>',
        'AcceptSelectionSplit'  => ['<C-CR>', '<C-s>'],
        'AcceptSelectionTab'    => '<C-t>',
        'AcceptSelectionVSplit' => '<C-v>',
        'Backspace'             => '<BS>',
        'Cancel'                => ['<C-c>', '<Esc>'],
        'Clear'                 => '<C-u>',
        'ClearPrevWord'         => '<C-w>',
        'CursorEnd'             => '<C-e>',
        'CursorLeft'            => ['<Left>', '<C-h>'],
        'CursorRight'           => ['<Right>', '<C-l>'],
        'CursorStart'           => '<C-a>',
        'Delete'                => '<Del>',
        'Quickfix'              => '<C-q>',
        'Refresh'               => '<C-f>',
        'SelectNext'            => ['<C-n>', '<C-j>', '<Down>'],
        'SelectPrev'            => ['<C-p>', '<C-k>', '<Up>'],
        'ToggleFocus'           => '<Tab>',
      }.each do |key, value|
        if override = VIM::get_list_or_string("g:CommandT#{key}Map")
          Array(override).each do |mapping|
            map mapping, key
          end
        else
          Array(value).each do |mapping|
            unless mapping == '<Esc>' && term =~ /\A(screen|xterm|vt100)/
              map mapping, key
            end
          end
        end
      end
    end

    def set_up_autocmds
      ::VIM::command 'augroup Command-T'
      ::VIM::command 'au!'
      ::VIM::command 'autocmd CursorHold <buffer> :call CommandTListMatches()'
      ::VIM::command 'augroup END'
    end

    # Returns the desired maximum number of matches, based on available vertical
    # space and the g:CommandTMaxHeight option.
    #
    # Note the "available" space is actually a theoretical upper bound; it takes
    # into account screen dimensions but not things like existing splits which
    # may reduce the amount of space in practice.
    def match_limit
      limit = [1, VIM::Screen.lines - 5].max
      limit = [limit, max_height].min if max_height > 0
      limit
    end

    def buffer_finder
      @buffer_finder ||= CommandT::BufferFinder.new
    end

    def mru_finder
      @mru_finder ||= CommandT::MRUBufferFinder.new
    end

    def file_finder
      @file_finder ||= CommandT::FileFinder.new nil,
        :max_depth              => VIM::get_number('g:CommandTMaxDepth'),
        :max_files              => VIM::get_number('g:CommandTMaxFiles'),
        :max_caches             => VIM::get_number('g:CommandTMaxCachedDirectories'),
        :always_show_dot_files  => VIM::get_bool('g:CommandTAlwaysShowDotFiles'),
        :never_show_dot_files   => VIM::get_bool('g:CommandTNeverShowDotFiles'),
        :scan_dot_directories   => VIM::get_bool('g:CommandTScanDotDirectories'),
        :wild_ignore            => VIM::get_string('g:CommandTWildIgnore'),
        :scanner                => VIM::get_string('g:CommandTFileScanner')
    end

    def jump_finder
      @jump_finder ||= CommandT::JumpFinder.new
    end

    def tag_finder
      @tag_finder ||= CommandT::TagFinder.new \
        :include_filenames => VIM::get_bool('g:CommandTTagIncludeFilenames')
    end
  end # class Controller
end # module CommandT
