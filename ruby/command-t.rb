# Copyright 2014-2015 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

module CommandT
  autoload :Controller,    'command-t/controller'
  autoload :Finder,        'command-t/finder'
  autoload :Metadata,      'command-t/metadata'
  autoload :MRU,           'command-t/mru'
  autoload :MatchWindow,   'command-t/match_window'
  autoload :PathUtilities, 'command-t/path_utilities'
  autoload :Prompt,        'command-t/prompt'
  autoload :SCMUtilities,  'command-t/scm_utilities'
  autoload :Scanner,       'command-t/scanner'
  autoload :Settings,      'command-t/settings'
  autoload :Stub,          'command-t/stub'
  autoload :Util,          'command-t/util'
  autoload :VIM,           'command-t/vim'
end # module CommandT
