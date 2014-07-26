# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/ext' # CommandT::Matcher
require 'command-t/finder'
require 'command-t/scanner/file_scanner/ruby_file_scanner'
require 'command-t/scanner/file_scanner/find_file_scanner'
require 'command-t/scanner/file_scanner/watchman_file_scanner'
require 'command-t/scanner/file_scanner/git_file_scanner'

module CommandT
  class FileFinder < Finder
    def initialize(path = Dir.pwd, options = {})
      case options.delete(:scanner)
      when 'ruby', nil # ruby is the default
        @scanner = FileScanner::RubyFileScanner.new(path, options)
      when 'find'
        @scanner = FileScanner::FindFileScanner.new(path, options)
      when 'watchman'
        @scanner = FileScanner::WatchmanFileScanner.new(path, options)
      when 'git'
        @scanner = FileScanner::GitFileScanner.new(path, options)
      else
        raise ArgumentError, "unknown scanner type '#{options[:scanner]}'"
      end

      @matcher = Matcher.new @scanner, options
    end

    def flush
      @scanner.flush
    end
  end # class FileFinder
end # module CommandT
