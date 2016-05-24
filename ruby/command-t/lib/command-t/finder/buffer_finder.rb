# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class BufferFinder < Finder
      def initialize
        @scanner = Scanner::BufferScanner.new
        @matcher = Matcher.new @scanner, :always_show_dot_files => true
      end

      def name
        'Buffers'
      end
    end
  end
end
