# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class HistoryFinder < Finder
      def initialize(options = {})
        @history_type = options[:history_type] # / or :
        @scanner = Scanner::HistoryScanner.new("silent history #{@history_type}")
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def open_selection(command, selection, options = {})
        escaped = VIM.escape_for_single_quotes(selection)
        ::VIM::command "call feedkeys('#{@history_type}#{escaped} ', 'nt')"
      end

      def prepare_selection(selection)
        # Pass selection through as-is, bypassing path-based stuff that the
        # controller would otherwise do, like `expand_path`,
        # `sanitize_path_string` and `relative_path_under_working_directory`.
        selection
      end

      def flush; end

      def name
        @history_type == ':' ? 'History' : 'Searches'
      end
    end
  end
end
