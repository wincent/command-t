# Copyright 2011-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    class LineScanner < Scanner
      def paths
        @lines ||= paths!
      end

    private

      def paths!
        # $curbuf is the Command-T match listing; we actually want the last
        # buffer, but passing `$`, `#`, `%` etc to `bufnr()` returns the wrong
        # value.
        number = ::VIM.evaluate("g:CommandTCurrentBuffer").to_i
        return [] unless number > 0
        buffer = nil
        (0...(::VIM::Buffer.count)).each do |n|
          buffer = ::VIM::Buffer[n]
          if buffer_number(buffer) == number
            break
          else
            buffer = nil
          end
        end
        return [] unless buffer

        (1..(buffer.length)).map do |n|
          line = buffer[n]
          unless line.match(/\A\s*\z/)
            line.sub(/\A\s*/, '') + ':' + n.to_s
          end
        end.compact
      end

      def buffer_number(buffer)
        buffer && buffer.number
      rescue Vim::DeletedBufferError
        # Beware of people manually deleting Command-T's hidden, unlisted buffer.
      end
    end
  end
end
