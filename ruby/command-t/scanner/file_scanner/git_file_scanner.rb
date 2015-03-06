# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class FileScanner
      # Uses git ls-files to scan for files
      class GitFileScanner < FindFileScanner
        LsFilesError = Class.new(::RuntimeError)

        def paths!
          Dir.chdir(@path) do
            all_files = list_files(%w[git ls-files --exclude-standard -z])

            if @scan_submodules
              base = nil
              list_files(%w[
                git submodule foreach --recursive
                git ls-files --exclude-standard -z
              ]).each do |path|
                if path =~ /\AEntering '(.*)'\n(.*)\z/
                  base = $~[1]
                  path = $~[2]
                end
                all_files.push(base + File::SEPARATOR + path)
              end
            end

            all_files.
              map { |path| path.chomp }.
              reject { |path| path_excluded?(path, 0) }.
              take(@max_files).
              to_a
          end
        rescue LsFilesError
          super
        rescue Errno::ENOENT
          # git executable not present and executable
          super
        end

      private

        def list_files(command)
          stdin, stdout, stderr = Open3.popen3(*command)
          stdout.read.split("\0")
        ensure
          raise LsFilesError if stderr && stderr.gets
        end

      end # class GitFileScanner
    end # class FileScanner
  end # class Scanner
end # module CommandT
