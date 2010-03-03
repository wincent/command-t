module VIM
  class Window
    def select
      return true if selected?
      initial = $curwin
      while true do
        VIM::command 'wincmd w'             # cycle through windows
        return true if $curwin == self      # have selected desired window
        return false if $curwin == initial  # have already looped through all
      end
    end

    def selected?
      $curwin == self
    end
  end # class Window
end # module VIM
