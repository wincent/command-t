# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class FileScanner
      # Uses git ls-files to scan for files
      class GitFileScanner < FindFileScanner

        def paths!
          super
        rescue Errno::ENOENT
          @nogit = true
          super
        end
      private

        def command
          return super if @nogit

          cmd = 'git ls-files --exclude-standard -cz'
          if @include_untracked
            cmd << ' --others'
          end
          if @scan_submodules
            cmd << <<-END
              # Same in submodules
              git submodule --quiet foreach --recursive '
                git ls-files --exclude-standard -z |
                  # Add $path (dir of submodule) to the start of each path.
                  awk "-vp=$path" "BEGIN{RS=\\"\\\\0\\";ORS =\\"\\\\0\\"}\\$0=p \\"#{File::SEPARATOR}\\" \\$0"
              '
            END
          end
          cmd
        end

        def drop
          return super if @nogit

          0
        end

        def scanner_failed status, result
          return super if @nogit

          @nogit = true
          paths!
        end
      end
    end
  end
end
