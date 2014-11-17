# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/ext' # CommandT::Matcher, CommandT::Watchman::Utils

module CommandT
  # Encapsulates a Scanner instance (which builds up a list of available files
  # in a directory) and a Matcher instance (which selects from that list based
  # on a search string).
  #
  # Specialized subclasses use different kinds of scanners adapted for
  # different kinds of search (files, buffers).
  class Finder
    autoload :BufferFinder,    'command-t/finder/buffer_finder'
    autoload :FileFinder,      'command-t/finder/file_finder'
    autoload :JumpFinder,      'command-t/finder/jump_finder'
    autoload :MRUBufferFinder, 'command-t/finder/mru_buffer_finder'
    autoload :TagFinder,       'command-t/finder/tag_finder'

    include PathUtilities

    def initialize(path = Dir.pwd, options = {})
      raise RuntimeError, 'Subclass responsibility'
    end

    # Options:
    #   :limit (integer): limit the number of returned matches
    def sorted_matches_for(str, options = {})
      @matcher.sorted_matches_for str, options
    end

    def open_selection(command, selection, options = {})
      ::VIM::command "silent #{command} #{selection}"
    end

    def path=(path)
      @scanner.path = path
    end
  end # class Finder
end # CommandT
