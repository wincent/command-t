# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class FileFinder < Finder
      def initialize(path = Dir.pwd, options = {})
        @scanner = Scanner::FileScanner.for_string(options.delete(:scanner)).new(path, options)
        @matcher = Matcher.new @scanner, options
      end

      def flush
        @scanner.flush
      end

      def name
        'Files'
      end
    end
  end
end
