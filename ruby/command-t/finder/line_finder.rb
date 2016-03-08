# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class LineFinder < Finder
      def initialize(options = {})
        @scanner = Scanner::LineScanner.new
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def open_selection(command, selection, options = {})
        ::VIM::command "#{selection.sub(/.+:(\d+)$/, '\1')}"
      end

      def flush; end

      def name
        'Lines'
      end
    end
  end
end
