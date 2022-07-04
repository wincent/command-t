# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

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
