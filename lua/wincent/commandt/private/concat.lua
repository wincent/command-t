-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Utility function that concatenates one or more list-like tables into a new
--- list.
---
--- @param ... any[]
--- @return any[]
local function concat(...)
  local final = {}
  for _, t in ipairs({ ... }) do
    for _, v in ipairs(t) do
      table.insert(final, v)
    end
  end
  return final
end

return concat
