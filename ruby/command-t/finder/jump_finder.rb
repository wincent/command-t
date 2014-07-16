# Copyright 2011-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/ext' # CommandT::Matcher
require 'command-t/scanner/jump_scanner'
require 'command-t/finder'

module CommandT
  class JumpFinder < Finder
    def initialize
      @scanner = JumpScanner.new
      @matcher = Matcher.new @scanner, :always_show_dot_files => true
    end
  end # class JumpFinder
end # module CommandT
