# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

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
