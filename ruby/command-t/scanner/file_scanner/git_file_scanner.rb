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

            submodule_merger = lambda { |path| path }

            if @scan_submodules
              stdin_sub, stdout_sub, stderr_sub = Open3.popen(*[
                'git',
                'submodule',
                'foreach',
                'git',
                'ls-files'
              ])

              module_name = ''
              submodule_merger = lambda { |path|
                if (path =~ /^Entering '(.*)'$/) === 0
                  module_name = $~[1]
                end
                if module_name == ''
                  path
                else
                  module_name + '/' + path
                end
              }
            end

            # TODO: Merge stdout and stdout_sub...how?
            all_files = stdout.readlines.
              map { |path| path.chomp }.
              map { submodule_merger }.
              reject { |path| path_excluded?(path, 0) }.
              take(@max_files).
              to_a

            # will fall back to find if not a git repository or there's an error
            # TODO: merge stderr and stderr_sub...how?
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
