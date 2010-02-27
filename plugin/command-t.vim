" Copyright 2010 Wincent Colaiuta

if exists("f:command_t_loaded")
  finish
endif
let g:command_t_loaded = "loaded"

if !has("ruby")
  finish
endif

" commands
command CommandT :call <SID>CommandTShow()

" mappings
map <silent> <Leader>ct :CommandT<CR>

" functions

function! s:CommandTShow()
  ruby $command_t.show
endfunction

ruby << EOF
begin
  require 'command-t'
rescue LoadError
  lib = "#{ENV['HOME']}/.vim/ruby"
  raise if $LOAD_PATH.include?(lib)
  $LOAD_PATH << lib
  retry
end

module Screen
  def self.lines
    VIM.evaluate('&lines').to_i
  end

  def self.columns
    VIM.evaluate('&columns').to_i
  end
end # module Screen

module VIM
  def self.pwd
    VIM.evaluate('getcwd()')
  end
end

module CommandT
  class Controller
    def show
    end
  end # class Controller
end # module commandT

$command_t = CommandT::Controller.new
EOF
