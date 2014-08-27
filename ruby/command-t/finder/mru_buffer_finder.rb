# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/ext' # CommandT::Matcher
require 'command-t/scanner/mru_buffer_scanner'
require 'command-t/finder/buffer_finder'

module CommandT
  class MRUBufferFinder < BufferFinder
    def initialize
      @scanner = MRUBufferScanner.new
      @matcher = Matcher.new @scanner, :always_show_dot_files => true
    end

    # Override sorted_matches_for to prevent MRU ordered matches from being
    # ordered alphabetically.
    def sorted_matches_for(str, options = {})
      matches = super(str, options.merge(:sort => false))

      # take current buffer (by definition, the most recently used) and move it
      # to the end of the results
      if MRU.last &&
        relative_path_under_working_directory(MRU.last.name) == matches.first
        matches[1..-1] + [matches.first]
      else
        matches
      end
    end
  end # class MRUBufferFinder
end # CommandT
