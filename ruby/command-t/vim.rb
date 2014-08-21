# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/vim/screen'
require 'command-t/vim/window'

module CommandT
  module VIM
    class << self
      def has_syntax?
        ::VIM::evaluate('has("syntax")').to_i != 0
      end

      def exists?(str)
        ::VIM::evaluate(%{exists("#{str}")}).to_i != 0
      end

      def has_conceal?
        ::VIM::evaluate('has("conceal")').to_i != 0
      end

      def pwd
        ::VIM::evaluate 'getcwd()'
      end

      def wild_ignore
        exists?('&wildignore') && ::VIM::evaluate('&wildignore').to_s || ''
      end

      def current_file_dir
        ::VIM::evaluate 'expand("%:p:h")'
      end

      # Execute cmd, capturing the output into a variable and returning it.
      def capture(cmd)
        ::VIM::command 'silent redir => g:command_t_captured_output'
        ::VIM::command cmd
        ::VIM::command 'silent redir END'
        ::VIM::evaluate 'g:command_t_captured_output'
      end

      # Escape a string for safe inclusion in a Vim single-quoted string
      # (single quotes escaped by doubling, everything else is literal)
      def escape_for_single_quotes(str)
        str.gsub "'", "''"
      end
    end
  end # module VIM
end # module CommandT
