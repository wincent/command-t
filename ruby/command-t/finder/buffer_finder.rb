# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/ext' # CommandT::Matcher
require 'command-t/scanner/buffer_scanner'
require 'command-t/finder'

module CommandT
  class BufferFinder < Finder
    def initialize
      @scanner = BufferScanner.new
      @matcher = Matcher.new @scanner, :always_show_dot_files => true
    end
  end # class BufferFinder
end # CommandT
