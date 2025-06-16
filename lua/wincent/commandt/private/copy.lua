-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Utility function for creating a deep copy of a value.
---
--- Not depending on `vim.deepcopy()` so that we can use this anywhere (eg.
--- benchmarks, tests etc).
---
--- @generic T
--- @param t T
--- @return T
local function copy(t)
  if type(t) == 'table' then
    local final = {}
    for k, v in pairs(t) do
      if type(v) == 'table' then
        final[k] = copy(v)
      else
        final[k] = v
      end
    end
    return final
  else
    return t
  end
end

return copy
