# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class CommandFinder < Finder
      def initialize(options = {})
        @scanner = Scanner::CommandScanner.new
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def open_selection(command, selection, options = {})
        escaped = VIM.escape_for_single_quotes selection
        ::VIM::command "call feedkeys(':#{selection} ', 'nt')"
      end

      def prepare_selection(selection)
        # Pass selection through as-is, bypassing path-based stuff that the
        # controller would otherwise do, like `expand_path`,
        # `sanitize_path_string` and `relative_path_under_working_directory`.
        selection
      end

      def flush; end

      def name
        'Commands'
      end
    end
  end
end
