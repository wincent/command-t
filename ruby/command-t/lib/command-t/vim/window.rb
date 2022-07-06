# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  module VIM
    module Window
      class << self
        def select(window)
          return true if $curwin == window
          initial = $curwin
          while true do
            ::VIM::command 'wincmd w'          # cycle through windows
            return true if $curwin == window   # have selected desired window
            return false if $curwin == initial # have already looped through all
          end
        end
      end
    end
  end
end
