-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Utility function for working with functions that take optional arguments.
--
-- Creates a merged table containing items from the supplied tables, working
-- from left to right.
--
-- ie. `merge(t1, t2, t3)` will insert elements from `t1`, then `t2`, then
-- `t3` into a new table, then return the new table.
local merge = function(...)
  local final = {}
  for _, t in ipairs({ ... }) do
    if t ~= nil then
      for k, v in pairs(t) do
        final[k] = v
      end
    end
  end
  return final
end

return merge
