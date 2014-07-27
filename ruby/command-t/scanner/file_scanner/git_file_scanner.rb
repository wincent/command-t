# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/scanner/file_scanner/find_file_scanner'

module CommandT
  class FileScanner
    # Uses git ls-files to scan for files
    class GitFileScanner < FindFileScanner
      def paths
        @paths[@path] ||= begin
          Dir.chdir(@path) do
            set_wild_ignore(@wild_ignore)
            prepare_paths

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

            # either git is not available, or this is not a git repository
            # fall back to find
            return super if stderr.gets

            all_files
          end
        ensure
          set_wild_ignore(@base_wild_ignore)
        end
      end
    end # class GitFileScanner
  end # class FileScanner
end # module CommandT
