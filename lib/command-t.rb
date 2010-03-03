module CommandT
  # low-level modules (independent specs)
  autoload :Base, 'command-t/base'
  autoload :Match, 'command-t/match'
  autoload :Matcher, 'command-t/matcher'
  autoload :Scanner, 'command-t/scanner'

  # high-level modules (VIM integration)
  autoload :MatchWindow, 'command-t/match_window'
  autoload :Prompt, 'command-t/prompt'
end # module CommandT
