# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class SearchFinder < Finder
      def initialize(options = {})
        @scanner = Scanner::SearchScanner.new
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def open_selection(command, selection, options = {})
        # Need to unescape to reverse the work done by `#sanitize_path_string`.
        unescaped = selection.gsub(/\\(.)/, '\1')
        escaped = VIM.escape_for_single_quotes unescaped
        ::VIM::command "call feedkeys('/#{escaped}', 'nt')"
      end

      def flush; end

      def name
        'Searches'
      end
    end # class SearchFinder
  end # class Finder
end # module CommandT
