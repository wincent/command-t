# SPDX-FileCopyrightText: Copyright 2011-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

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
