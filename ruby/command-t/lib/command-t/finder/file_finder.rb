# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class FileFinder < Finder
      def initialize(path = Dir.pwd, options = {})
        @scanner = scanner(options.delete(:scanner), path, options)
        @matcher = Matcher.new @scanner, options
      end

      def flush
        @scanner.flush
      end

      def name
        'Files'
      end

    private

      def scanner(name, path, options)
        case name
        when 'ruby', nil # ruby is the default
          Scanner::FileScanner::RubyFileScanner.new(path, options)
        when 'find'
          Scanner::FileScanner::FindFileScanner.new(path, options)
        when 'watchman'
          Scanner::FileScanner::WatchmanFileScanner.new(path, options)
        when 'git'
          Scanner::FileScanner::GitFileScanner.new(path, options)
        else
          raise ArgumentError, "unknown scanner type '#{which}'"
        end
      end
    end
  end
end
