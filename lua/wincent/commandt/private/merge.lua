-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local merge = nil

local is_list = require('wincent.commandt.private.is_list')
local is_table = require('wincent.commandt.private.is_table')

-- Utility function for working with functions that take optional arguments.
--
-- Creates a merged table containing items from the supplied tables, working
-- from left to right, recursively.
--
-- ie. `merge(t1, t2, t3)` will insert elements from `t1`, then `t2`, then
-- `t3` into a new table, then return the new table.
--
-- Note that:
--
-- - Values of different types will overwrite rather than merge recursively.
-- - List-like tables will overwrite rather than merge (because it is convenient
--   for user settings).
-- - Table-like tables _will_ merge recursively.
--
-- We're not depending on `vim.tbl_deep_extend()` so that we can use this
-- anywhere (eg. benchmarks, tests etc).
merge = function(...)
  local final = {}
  for _, t in ipairs({ ... }) do
    if t ~= nil then
      for k, v in pairs(t) do
        if is_list(final[k]) and is_list(v) then
          final[k] = v
        elseif is_table(final[k]) and is_table(v) then
          final[k] = merge(final[k], v)
        else
          final[k] = v
        end
      end
    end
  end
  return final
end

return merge
