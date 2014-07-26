# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/vim'
require 'command-t/scanner/file_scanner'
require 'open3'

module CommandT
  class FileScanner
    # Uses git ls-files to scan for files
    class GitFileScanner < FindFileScanner
      def paths
        @paths[@path] ||= Dir.chdir(@path) do
          prepare_paths

          command = "git ls-files --exclude-standard "
          stdin, stdout, stderr = Open3.popen3(*[
            "git",
            "ls-files",
            "--exclude-standard",
            @path
          ])

          set_wild_ignore(@wild_ignore)
          all_files = stdout.readlines.
            map { |x| x.chomp }.
            select { |x| not path_excluded?(x, prefix_len = 0) }.
            take(@max_files).
            to_a

          # either git is not available, or this is not a git repository
          # fall back to find
          return super if stderr.gets

          all_files
        end
      end
    end # class GitFileScanner
  end # class FileScanner
end # module CommandT
