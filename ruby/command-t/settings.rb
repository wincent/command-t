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
    def initialize
      @settings = []
    end

    def set(setting, value)
      case value
      when TrueClass, FalseClass
        @settings.push([setting, get_bool(setting)])
        set_bool setting, value
      when Numeric
        @settings.push([setting, get_number(setting)])
        set_number setting, value
      end
    end

    def restore
      @settings.each do |setting, value|
        case value
        when TrueClass, FalseClass
          set_bool setting, value
        when Numeric
          set_number setting, value
        end
      end
    end

  private

    def get_number(setting)
      ::VIM::evaluate("&#{setting}").to_i
    end

    def get_bool(setting)
      ::VIM::evaluate("&#{setting}").to_i == 1
    end

    def set_number(setting, value)
      ::VIM::set_option "#{setting}=#{value}"
    end

    def set_bool(setting, value)
      if value
        ::VIM::set_option setting
      else
        ::VIM::set_option "no#{setting}"
      end
    end
  end # class Settings
end # module CommandT
