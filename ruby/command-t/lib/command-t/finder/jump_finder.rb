# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class JumpFinder < Finder
      def initialize
        @scanner = Scanner::JumpScanner.new
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def name
        'Jumps'
      end
    end
  end
end
