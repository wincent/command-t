module CommandT
  # Convenience class for saving and restoring global settings.
  class Settings
    def save
      @timeoutlen     = get_number 'timeoutlen'
      @report         = get_number 'report'
      @sidescroll     = get_number 'sidescroll'
      @sidescrolloff  = get_number 'sidescrolloff'
      @equalalways    = get_bool 'equalalways'
      @hlsearch       = get_bool 'hlsearch'
      @insertmode     = get_bool 'insertmode'
      @showcmd        = get_bool 'showcmd'
      @list           = get_bool 'list'
    end

    def restore
      set_number 'timeoutlen', @timeoutlen
      set_number 'report', @report
      set_number 'sidescroll', @sidescroll
      set_number 'sidescrolloff', @sidescrolloff
      set_bool 'equalalways', @equalalways
      set_bool 'hlsearch', @hlsearch
      set_bool 'insertmode', @insertmode
      set_bool 'showcmd', @showcmd
      set_bool 'list', @list
    end

  private

    def get_number setting
      VIM::evaluate("&#{setting}").to_i
    end

    def get_bool setting
      VIM::evaluate("&#{setting}").to_i == 1
    end

    def set_number setting, value
      VIM::set_option "#{setting}=#{value}"
    end

    def set_bool setting, value
      if value
        VIM::set_option setting
      else
        VIM::set_option "no#{setting}"
      end
    end
  end # class Settings
end # module CommandT
