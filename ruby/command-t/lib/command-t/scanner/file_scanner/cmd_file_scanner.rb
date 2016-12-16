# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class FileScanner
      # Uses git ls-files to scan for files
      class CmdFileScanner < FindFileScanner
        def initialize path = Dir.pwd, options = {}
          super
          @cmd = options.fetch :custom_cmd

          @term = options[:custom_cmd_terminator] || "\n"
          @term = "\0" if @term.empty?
        end
      private

        def command
          @cmd
        end

        def drop
          0
        end

        def terminator
          @term
        end
      end
    end
  end
end
