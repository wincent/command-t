# Copyright 2011-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class TagFinder < Finder
      def initialize(options = {})
        @scanner = Scanner::TagScanner.new options
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def open_selection(command, selection, options = {})
        if @scanner.include_filenames
          selection = selection[0, selection.index(':')]
        end

        #  open the tag and center the screen on it
        ::VIM::command "silent! tag #{selection} | :normal zz"
      end

      def flush
        @scanner.flush
      end
    end # class TagFinder
  end # class Finder
end # module CommandT
