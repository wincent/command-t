# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/vim/path_utilities'
require 'command-t/scanner/buffer_scanner'

module CommandT
  # Returns a list of all open buffers, sorted in MRU order.
  class MRUBufferScanner < BufferScanner
    include VIM::PathUtilities

    def paths
      # Collect all buffers that have not been used yet.
      unused_buffers = (0..(::VIM::Buffer.count - 1)).map do |n|
        buffer = ::VIM::Buffer[n]
        buffer if buffer.name && !MRU.used?(buffer)
      end

      # Combine all most recently used buffers and all unused buffers, and
      # return all listed buffer paths.
      (unused_buffers + MRU.stack).map do |buffer|
        if buffer && buffer.name
          relative_path_under_working_directory buffer.name
        end
      end.compact.reverse
    end
  end # class MRUBufferScanner
end # module CommandT
