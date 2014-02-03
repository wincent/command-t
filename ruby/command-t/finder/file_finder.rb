# Copyright 2010-2014 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

require 'command-t/ext' # CommandT::Matcher
require 'command-t/finder'
require 'command-t/scanner/file_scanner/ruby_file_scanner'
require 'command-t/scanner/file_scanner/find_file_scanner'
require 'command-t/scanner/file_scanner/watchman_file_scanner'

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
