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
      if $curbuf.name
        @mru_buffer_stack.delete $curbuf
      end
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
        buffer if buffer.name and not @mru_buffer_stack.include?(buffer)
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
