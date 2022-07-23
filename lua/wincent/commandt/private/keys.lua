-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local keys = nil

-- Utility function that returns a list of keys in the given table.
keys = function(t)
  local final = {}
  for k, _ in pairs(t) do
    table.insert(final, k)
  end
  return final
end

return keys
