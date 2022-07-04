# SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell. All rights reserved.
# SPDX-License-Identifier: BSD-2-Clause

module CommandT
  module VIM
    module Screen
      class << self
        def lines
          ::VIM::evaluate('&lines').to_i
        end
      end
    end
  end
end
