# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class FileScanner
      # Uses git ls-files to scan for files
      class GitFileScanner < FindFileScanner
        LsFilesError = Class.new(::RuntimeError)

        def paths!
          Dir.chdir(@path) do
            command = %w[git ls-files --exclude-standard -cz]
            if @include_untracked
              command << %q(--others)
            end
            all_files = list_files(command)

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

            filtered = all_files.
              map { |path| path.chomp }.
              reject { |path| path_excluded?(path, 0) }
            truncated = filtered.take(@max_files)
            if truncated.count < filtered.count
              show_max_files_warning
            end
            truncated.to_a
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

      end
    end
  end
end
