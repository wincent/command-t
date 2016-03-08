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
        # Need to unescape to reverse the work done by `#sanitize_path_string`.
        unescaped = selection.gsub(/\\(.)/, '\1')
        escaped = VIM.escape_for_single_quotes unescaped
        ::VIM::command "call feedkeys('#{@history_type}#{escaped} ', 'nt')"
      end

      def flush; end

      def name
        @history_type == ':' ? 'History' : 'Searches'
      end
    end
  end
end
