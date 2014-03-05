# Copyright 2010-2014 Wincent Colaiuta. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

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
        @settings.push([setting, get_bool(setting)]) if global?(setting)
        set_bool setting, value
      when Numeric
        @settings.push([setting, get_number(setting)]) if global?(setting)
        set_number setting, value
      when String
        @settings.push([setting, get_string(setting)]) if global?(setting)
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

    def get_bool(setting)
      ::VIM::evaluate("&#{setting}").to_i == 1
    end

    def get_number(setting)
      ::VIM::evaluate("&#{setting}").to_i
    end

    def get_string(name)
      ::VIM::evaluate("&#{name}").to_s
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
