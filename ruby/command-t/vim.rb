# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/vim/screen'
require 'command-t/vim/window'

module CommandT
  module VIM
    class << self
      # Check for the existence of a feature such as "conceal" or "syntax".
      def has?(feature)
        ::VIM::evaluate(%{has("#{feature}")}).to_i != 0
      end

      # Check for the presence of a setting such as:
      #
      #   - g:CommandTSmartCase (plug-in setting)
      #   - &wildignore         (Vim setting)
      #   - +cursorcolumn       (Vim setting, that works)
      #
      def exists?(str)
        ::VIM::evaluate(%{exists("#{str}")}).to_i != 0
      end

      def get_number(name)
        exists?(name) ? ::VIM::evaluate("#{name}").to_i : nil
      end

      def get_bool(name)
        exists?(name) ? ::VIM::evaluate("#{name}").to_i != 0 : nil
      end

      def get_string(name)
        exists?(name) ? ::VIM::evaluate("#{name}").to_s : nil
      end

      # expect a string or a list of strings
      def get_list_or_string(name)
        return nil unless exists?(name)
        list_or_string = ::VIM::evaluate("#{name}")
        if list_or_string.kind_of?(Array)
          list_or_string.map { |item| item.to_s }
        else
          list_or_string.to_s
        end
      end

      def pwd
        ::VIM::evaluate 'getcwd()'
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
