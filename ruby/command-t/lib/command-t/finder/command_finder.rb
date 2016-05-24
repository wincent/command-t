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
        ::VIM::command "call feedkeys(':#{selection} ', 'nt')"
      end

      def flush; end

      def name
        'Commands'
      end
    end
  end
end
