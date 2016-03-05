# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    autoload :BufferScanner,    'command-t/scanner/buffer_scanner'
    autoload :CommandScanner,   'command-t/scanner/command_scanner'
    autoload :FileScanner,      'command-t/scanner/file_scanner'
    autoload :HelpScanner,      'command-t/scanner/help_scanner'
    autoload :HistoryScanner,   'command-t/scanner/history_scanner'
    autoload :JumpScanner,      'command-t/scanner/jump_scanner'
    autoload :LineScanner,      'command-t/scanner/line_scanner'
    autoload :MRUBufferScanner, 'command-t/scanner/mru_buffer_scanner'
    autoload :TagScanner,       'command-t/scanner/tag_scanner'

    # Subclasses implement this method to return the list of paths that should
    # be searched.
    #
    # Note that as an optimization, the C extension will record the
    # `Object#object_id` of the returned array and assumes it will not be
    # mutated.
    def paths
      raise RuntimeError, 'Subclass responsibility'
    end

  private

    SPINNER = %w[^ > v <]
    def report_progress(count)
      @spinner ||= SPINNER.first
      @spinner = SPINNER[(SPINNER.index(@spinner) + 1) % SPINNER.length]

      ::VIM::command "echon '#{@spinner}  #{count}'"
      ::VIM::command 'redraw'

      # Slow down updates as results set size increases to reduce overhead.
      # Apply a random jitter to make things "interesting".
      # But don't slow down too much.
      count + [count / 100, 2_000].min + rand(10) + 1
    end
  end # class Scanner
end # module CommandT
