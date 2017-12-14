# Copyright 2014-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'set'

module CommandT
  # Maintains a stack of seen buffer numbers in MRU (most recently used) order.
  module MRU
    class << self
      # The stack of used buffer numbers in MRU order.
      def stack
        @stack ||= []
      end

      # All buffer numbers in the stack, returned as a set for fast membership
      # lookup.
      def buffers
        Set.new(@stack)
      end

      # The (last) most recent buffer number in the stack, if any.
      def last
        stack.last
      end

      # Mark the current buffer as having been used, effectively moving it to
      # the top of the stack. Has no effect on unlisted buffers or buffers
      # without names.
      def touch
        number = $curbuf.number
        return unless ::VIM::evaluate('buflisted(%d)' % number) == 1
        return unless $curbuf.name

        stack.delete number
        stack.push number
      end

      # Mark a buffer as deleted, removing it from the stack.
      def delete
        # Note that $curbuf does not point to the buffer that is being deleted;
        # we need to use Vim's <abuf> for the correct buffer number.
        current = ::VIM::evaluate('expand("<abuf>")').to_i
        stack.delete_if { |number| number == current }
      end
    end
  end
end
