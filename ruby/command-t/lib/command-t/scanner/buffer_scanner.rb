# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    # Returns a list of all open buffers.
    class BufferScanner < Scanner
      include PathUtilities

      def paths
        (0..(::VIM::Buffer.count - 1)).map do |n|
          buffer = ::VIM::Buffer[n]
          # Beware, name may be nil, and on Neovim unlisted buffers (like
          # Command-T's match listing itself) will be returned and must be
          # skipped.
          if buffer.name && ::VIM::evaluate("buflisted(#{buffer.number})") != 0
            relative_path_under_working_directory buffer.name
          end
        end.compact
      end
    end
  end
end
