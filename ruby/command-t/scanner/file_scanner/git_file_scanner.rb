# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class FileScanner
      # Uses git ls-files to scan for files
      class GitFileScanner < FindFileScanner
        def paths!
          Dir.chdir(@path) do
            stdin, stdout, stderr = Open3.popen3(*[
              'git',
              'ls-files',
              '--exclude-standard',
              @path
            ])

            all_files = stdout.readlines.
              map { |path| path.chomp }.
              reject { |path| path_excluded?(path, 0) }.
              take(@max_files).
              to_a

            # will fall back to find if not a git repository or there's an error
            stderr.gets ? super : all_files
          end
        rescue Errno::ENOENT => e
          # git executable not present and executable
          super
        end
      end # class GitFileScanner
    end # class FileScanner
  end # class Scanner
end # module CommandT
