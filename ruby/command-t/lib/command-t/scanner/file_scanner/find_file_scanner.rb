# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'open3'

module CommandT
  class Scanner
    class FileScanner
      # A FileScanner which shells out to the `find` executable in order to scan.
      class FindFileScanner < FileScanner
        def paths!
          Dir.chdir @path do
            Open3.popen2 command do |stdin, stdout, waitthread|
              stdin.close
              r = CommandT::Paths.from_fd stdout.fileno, terminator,
                drop: drop,
                limit: @max_files,
                update: update,
                where: filter
              stdout.close
              status = waitthread.value
              if status.success?
                r
              else
                scanner_failed status, r
              end
            end
          end
        end

      private

        def command
          # -L: follow symlinks
          "find -L . -maxdepth #{@max_depth + 1} #{dot_directory_filter} -type f -print0"
        end

        def drop
          2 # Drop leading ./
        end

        def terminator
          "\0"
        end

        def dot_directory_filter
          if @scan_dot_directories
            ''
          else
            # The ? is to prevent matching '.'
            '-name ".?*" -prune -o'
          end
        end

        def filter
          if @wildignore
            lambda { |p| !path_excluded? p }
          end
        end

        def update
           lambda { |count| progress_reporter.update count }
        end

        def scanner_failed status, result
          result # Return what we have by default
        end
      end
    end
  end
end
