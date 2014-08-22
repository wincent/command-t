# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/vim/path_utilities'
require 'command-t/scanner'

module CommandT
  # Returns a list of all open buffers.
  class BufferScanner < Scanner
    include VIM::PathUtilities

    def paths
      (0..(::VIM::Buffer.count - 1)).map do |n|
        buffer = ::VIM::Buffer[n]
        if buffer.name # beware, may be nil
          relative_path_under_working_directory buffer.name
        end
      end.compact
    end
  end # class BufferScanner
end # module CommandT
