# Copyright 2011-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class JumpFinder < Finder
      def initialize
        @scanner = Scanner::JumpScanner.new
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end
    end # class JumpFinder
  end # class Finder
end # module CommandT
