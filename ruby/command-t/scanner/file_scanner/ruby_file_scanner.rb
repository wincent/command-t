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

require 'command-t/vim'
require 'command-t/scanner/file_scanner'

module CommandT
  class FileScanner
    # Pure Ruby implementation of a file scanner.
    class RubyFileScanner < FileScanner
      def paths
        super || begin
          @paths[@path] = []
          @depth        = 0
          @files        = 0
          set_wild_ignore(@wild_ignore)
          add_paths_for_directory @path, @paths[@path]
        rescue FileLimitExceeded
        ensure
          set_wild_ignore(@base_wild_ignore)
        end
        @paths[@path]
      end

    private

      def looped_symlink? path
        if File.symlink?(path)
          target = File.expand_path(File.readlink(path), File.dirname(path))
          target.include?(@path) || @path.include?(target)
        end
      end

      def add_paths_for_directory dir, accumulator
        Dir.foreach(dir) do |entry|
          next if ['.', '..'].include?(entry)
          path = File.join(dir, entry)
          unless path_excluded?(path)
            if File.file?(path)
              @files += 1
              raise FileLimitExceeded if @files > @max_files
              accumulator << path[@prefix_len + 1..-1]
            elsif File.directory?(path)
              next if @depth >= @max_depth
              next if (entry.match(/\A\./) && !@scan_dot_directories)
              next if looped_symlink?(path)
              @depth += 1
              add_paths_for_directory path, accumulator
              @depth -= 1
            end
          end
        end
      rescue Errno::EACCES
        # skip over directories for which we don't have access
      end
    end # class RubyFileScanner
  end # class FileScanner
end # module CommandT
