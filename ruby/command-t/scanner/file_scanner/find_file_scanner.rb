# Copyright 2014 Wincent Colaiuta. All rights reserved.
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

require 'open3'
require 'command-t/vim'
require 'command-t/vim/path_utilities'
require 'command-t/scanner/file_scanner'

module CommandT
  class FileScanner
    # A FileScanner which shells out to the `find` executable in order to scan.
    class FindFileScanner < FileScanner
      include VIM::PathUtilities

      def paths
        super || begin
          set_wild_ignore(@wild_ignore)

          # temporarily set field separator to NUL byte; this setting is
          # respected by both `readlines` and `chomp!` below, and makes it easier
          # to parse the output of `find -print0`
          separator = $/
          $/ = "\x00"

          unless @scan_dot_directories
            dot_directory_filter = [
              '-not', '-path', "#{@path}/.*/*",           # top-level dot dir
              '-and', '-not', '-path', "#{@path}/*/.*/*"  # lower-level dot dir
            ]
          end

          Open3.popen3(*([
            'find', '-L',                 # follow symlinks
            @path,                        # anchor search here
            '-maxdepth', @max_depth.to_s, # limit depth of DFS
            '-type', 'f',                 # only show regular files (not dirs etc)
            dot_directory_filter,         # possibly skip out dot directories
            '-print0'                     # NUL-terminate results
          ].flatten.compact)) do |stdin, stdout, stderr|
            counter = 1
            paths = []
            stdout.readlines.each do |line|
              next if path_excluded?(line.chomp!)
              paths << line[@prefix_len + 1..-1]
              break if (counter += 1) > @max_files
            end
            @paths[@path] = paths
          end
        ensure
          $/ = separator
          set_wild_ignore(@base_wild_ignore)
        end
        @paths[@path]
      end
    end # class FindFileScanner
  end # class FileScanner
end # module CommandT
