# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/scanner/file_scanner'

module CommandT
  class FileScanner
    # Pure Ruby implementation of a file scanner.
    class RubyFileScanner < FileScanner
      def paths!
        accumulator = []
        @depth = 0
        @files = 0
        add_paths_for_directory(@path, accumulator)
        accumulator
      rescue FileLimitExceeded
        accumulator
      end

    private

      def looped_symlink?(path)
        if File.symlink?(path)
          target = File.expand_path(File.readlink(path), File.dirname(path))
          target.include?(@path) || @path.include?(target)
        end
      end

      def add_paths_for_directory(dir, accumulator)
        Dir.foreach(dir) do |entry|
          next if ['.', '..'].include?(entry)
          path = File.join(dir, entry)
          unless path_excluded?(path)
            if File.file?(path)
              @files += 1
              raise FileLimitExceeded if @files > @max_files
              accumulator << path[@prefix_len..-1]
            elsif File.directory?(path)
              next if @depth >= @max_depth
              next if (entry.match(/\A\./) && !@scan_dot_directories)
              next if looped_symlink?(path)
              @depth += 1
              add_paths_for_directory(path, accumulator)
              @depth -= 1
            end
          end
        end
      rescue Errno::EACCES
        # skip over directories for which we don't have access
      rescue ArgumentError
        # skip over bad file names
      end
    end # class RubyFileScanner
  end # class FileScanner
end # module CommandT
