-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local contains = nil

-- Utility function to determine whether a value exists in a list.
--
-- Use only for small `n` due to `O(n)` linear scan.
contains = function(list, desired)
  for _, actual in ipairs(list) do
    if actual == desired then
      return true
    end
  end
  return false
end

return contains
