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

require 'command-t/vim/path_utilities'
require 'command-t/scanner'

module CommandT
  # Returns a list of all open buffers.
  class MruBufferScanner < Scanner
    include VIM::PathUtilities

    def initialize
      @mru_buffer_stack = []

      $scanner = self
      ::VIM::command 'augroup CommandTMruBufferScanner'
      ::VIM::command 'autocmd!'
      ::VIM::command 'autocmd BufEnter * ruby $scanner.mark_buffer_used'
      ::VIM::command 'autocmd BufDelete * ruby $scanner.delete_buffer'
      ::VIM::command 'augroup End'
    end

    def delete_buffer
      # Note that $curbuf does not point to the buffer that is being deleted,
      # we need to use Vim's abuf for the correct buffer number.
      @mru_buffer_stack.delete_if { |b| b.number == ::VIM::evaluate('expand("<abuf>")').to_i }
    end

    def mark_buffer_used
      if $curbuf.name
        # Mark the current buffer as the most recently used buffer by placing
        # it in front of all other buffers listed in the list of most
        # recently used buffers.
        @mru_buffer_stack.delete $curbuf
        @mru_buffer_stack.unshift $curbuf
      end
    end

    def paths
      # Collect all buffers that have not been used yet.
      unused_buffers = (0..(::VIM::Buffer.count - 1)).map do |n|
        buffer = ::VIM::Buffer[n]
        buffer if buffer.name && !@mru_buffer_stack.include?(buffer)
      end.compact

      # Combine all most recently used buffers and all unused buffers, and
      # return all listed buffer paths.
      (@mru_buffer_stack + unused_buffers).map do |buffer|
        if ::VIM::evaluate('buflisted(%d)' % buffer.number) == 1
          relative_path_under_working_directory buffer.name
        end
      end.compact
    end
  end # class MruBufferScanner
end # module CommandT
