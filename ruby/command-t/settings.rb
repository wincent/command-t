# Copyright 2010-2014 Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

require 'command-t/vim'

module CommandT
  # Convenience class for saving and restoring global settings.
  class Settings
    # Settings which apply globally and so must be manually saved and restored
    GLOBAL_SETTINGS = %w[
      equalalways
      hlsearch
      insertmode
      report
      showcmd
      scrolloff
      sidescroll
      sidescrolloff
      timeout
      timeoutlen
      updatetime
    ]

    # Settings which can be made locally to the Command-T buffer or window
    LOCAL_SETTINGS = %w[
      bufhidden
      buflisted
      buftype
      colorcolumn
      concealcursor
      conceallevel
      cursorline
      foldcolumn
      foldlevel
      list
      modifiable
      number
      relativenumber
      spell
      swapfile
      synmaxcol
      textwidth
      wrap
    ]

    KNOWN_SETTINGS = GLOBAL_SETTINGS + LOCAL_SETTINGS

    def initialize
      @settings = []
    end

    def set(setting, value)
      raise "Unknown setting #{setting}" unless KNOWN_SETTINGS.include?(setting)

      case value
      when TrueClass, FalseClass
        @settings.push([setting, VIM::get_bool("&#{setting}")]) if global?(setting)
        set_bool setting, value
      when Numeric
        @settings.push([setting, VIM::get_number("&#{setting}")]) if global?(setting)
        set_number setting, value
      when String
        @settings.push([setting, VIM::get_string("&#{setting}")]) if global?(setting)
        set_string setting, value
      end
    end

    def restore
      @settings.each do |setting, value|
        case value
        when TrueClass, FalseClass
          set_bool setting, value
        when Numeric
          set_number setting, value
        when String
          set_string setting, value
        end
      end
    end

  private

    def global?(setting)
      GLOBAL_SETTINGS.include?(setting)
    end

    def set_bool(setting, value)
      command = global?(setting) ? 'set' : 'setlocal'
      setting = value ? setting : "no#{setting}"
      ::VIM::command "#{command} #{setting}"
    end

    def set_number(setting, value)
      command = global?(setting) ? 'set' : 'setlocal'
      ::VIM::command "#{command} #{setting}=#{value}"
    end
    alias set_string set_number
  end # class Settings
end # module CommandT
