# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Finder
    class FileFinder < Finder
      def initialize(path = Dir.pwd, options = {})
        case options.delete(:scanner)
        when 'ruby', nil # ruby is the default
          @scanner = Scanner::FileScanner::RubyFileScanner.new(path, options)
        when 'find'
          @scanner = Scanner::FileScanner::FindFileScanner.new(path, options)
        when 'watchman'
          @scanner = Scanner::FileScanner::WatchmanFileScanner.new(path, options)
        when 'git'
          @scanner = Scanner::FileScanner::GitFileScanner.new(path, options)
        else
          raise ArgumentError, "unknown scanner type '#{options[:scanner]}'"
        end

        @matcher = Matcher.new @scanner, options
      end

      def flush
        @scanner.flush
      end
    end # class FileFinder
  end # class Finder
end # module CommandT
