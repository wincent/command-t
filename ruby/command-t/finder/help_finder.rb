# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class HelpFinder < Finder
      def initialize(options = {})
        @scanner = Scanner::HelpScanner.new
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def open_selection(command, selection, options = {})
        ::VIM::command "help #{selection}"
      end

      def flush
        @scanner.flush
      end

      def name
        'Help'
      end
    end
  end
end
