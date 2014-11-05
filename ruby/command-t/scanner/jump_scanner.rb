# Copyright 2011-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    # Returns a list of files in the jumplist.
    class JumpScanner < Scanner
      include PathUtilities

      def paths
        jumps_with_filename = jumps.lines.select do |line|
          line_contains_filename?(line)
        end
        filenames = jumps_with_filename[1..-2].map do |line|
          relative_path_under_working_directory line.split[3]
        end

        filenames.sort.uniq
      end

    private

      def line_contains_filename?(line)
        line.split.count > 3
      end

      def jumps
        VIM::capture 'silent jumps'
      end
    end # class JumpScanner
  end # class Scanner
end # module CommandT
