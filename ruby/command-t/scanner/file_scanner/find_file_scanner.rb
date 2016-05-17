# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'open3'

module CommandT
  class Scanner
    class FileScanner
      # A FileScanner which shells out to the `find` executable in order to scan.
      class FindFileScanner < FileScanner
        include PathUtilities

        def paths!
          # temporarily set field separator to NUL byte; this setting is
          # respected by both `each_line` and `chomp!` below, and makes it easier
          # to parse the output of `find -print0`
          separator = $/
          $/ = "\x00"

          unless @scan_dot_directories
            dot_directory_filter = [
              '-not', '-path', "#{@path}/.*/*",           # top-level dot dir
              '-and', '-not', '-path', "#{@path}/*/.*/*"  # lower-level dot dir
            ]
          end

          paths = []
          Open3.popen3(*([
            'find', '-L',                 # follow symlinks
            @path,                        # anchor search here
            '-maxdepth', @max_depth.to_s, # limit depth of DFS
            '-type', 'f',                 # only show regular files (not dirs etc)
            dot_directory_filter,         # possibly skip out dot directories
            '-print0'                     # NUL-terminate results
          ].flatten.compact)) do |stdin, stdout, stderr|
            counter = 1
            next_progress = progress_reporter.update(counter)
            stdout.each_line do |line|
              next if path_excluded?(line.chomp!)
              paths << line[@prefix_len..-1]
              next_progress = progress_reporter.update(counter) if counter == next_progress
              if (counter += 1) > @max_files
                show_max_files_warning
                break
              end
            end
          end
          paths
        ensure
          $/ = separator
        end
      end
    end
  end
end
