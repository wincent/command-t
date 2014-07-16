# Copyright 2011-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/ext' # CommandT::Matcher
require 'command-t/scanner/tag_scanner'
require 'command-t/finder'

module CommandT
  class TagFinder < Finder
    def initialize options = {}
      @scanner = TagScanner.new options
      @matcher = Matcher.new @scanner, :always_show_dot_files => true
    end

    def open_selection command, selection, options = {}
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
end # module CommandT
