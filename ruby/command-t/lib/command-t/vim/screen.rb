# Copyright 2010-present Greg Hurrell. All rights reserved.
# Licensed under the terms of the BSD 2-clause license.

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
