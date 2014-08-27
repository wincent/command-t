# Copyright 2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  # Maintains a stack of seen buffers in MRU (most recently used) order.
  module MRU
    class << self
      # The stack of used buffers in MRU order.
      def stack
        @stack ||= []
      end

      # The (last) most recent buffer in the stack, if any.
      def last
        stack.last
      end

      # Mark the current buffer as having been used, effectively moving it to
      # the top of the stack.
      def touch
        return unless ::VIM::evaluate('buflisted(%d)' % $curbuf.number) == 1
        return unless $curbuf.name

        stack.delete $curbuf
        stack.push $curbuf
      end

      # Mark a buffer as deleted, removing it from the stack.
      def delete
        # Note that $curbuf does not point to the buffer that is being deleted;
        # we need to use Vim's <abuf> for the correct buffer number.
        stack.delete_if do |b|
          b.number == ::VIM::evaluate('expand("<abuf>")').to_i
        end
      end

      # Returns `true` if `buffer` has been used (ie. is present in the stack).
      def used?(buffer)
        stack.include?(buffer)
      end
    end
  end # module MRU
end # module CommandT
