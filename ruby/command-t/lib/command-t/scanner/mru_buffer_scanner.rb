# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    # Returns a list of all open buffers, sorted in MRU order.
    class MRUBufferScanner < BufferScanner
      include PathUtilities

      def paths
        @paths ||= paths!
      end

    private

      def paths!
        # Collect all buffers that have not been used yet.
        used_buffers = MRU.buffers
        unused_buffers = VIM.capture('silent ls').scan(/\n\s*(\d+)[^\n]+/).map do |n|
          number = n[0].to_i
        end.select { |n| !used_buffers.member?(n) }

        # Combine all most recently used buffers and all unused buffers, and
        # return all listed buffer paths.
        (unused_buffers + MRU.stack).map do |number|
          name = ::VIM.evaluate("bufname(#{number})")
          relative_path_under_working_directory(name) unless name == ''
        end.compact.reverse
      end
    end
  end
end
