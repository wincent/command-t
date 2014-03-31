# Copyright 2014 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

module CommandT
  # Maintains a stack of seen buffers in MRU (most recently used) order.
  module MRU
    class << self
      # The stack of used buffers in MRU order.
      def stack
        @stack ||= []
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
