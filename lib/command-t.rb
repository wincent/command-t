module CommandT
  # C extension
  autoload :Match,        'command-t/ext'

  # low-level modules (independent specs)
  autoload :Base,         'command-t/base'
  autoload :Matcher,      'command-t/matcher'
  autoload :Scanner,      'command-t/scanner'

  # high-level modules (VIM integration)
  autoload :Controller,   'command-t/controller'
  autoload :MatchWindow,  'command-t/match_window'
  autoload :Prompt,       'command-t/prompt'
  autoload :Settings,     'command-t/settings'
end # module CommandT
