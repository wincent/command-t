# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  class Scanner
    autoload :BufferScanner,    'command-t/scanner/buffer_scanner'
    autoload :FileScanner,      'command-t/scanner/file_scanner'
    autoload :JumpScanner,      'command-t/scanner/jump_scanner'
    autoload :MRUBufferScanner, 'command-t/scanner/mru_buffer_scanner'
    autoload :TagScanner,       'command-t/scanner/tag_scanner'
  end # class Scanner
end # module CommandT
