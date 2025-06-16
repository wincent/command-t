-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Returns `true` if `value` exists in list-like table, `t`.
---
--- @param t any[]
--- @param value any
--- @return boolean
local function includes(t, value)
  for _, candidate in ipairs(t) do
    if candidate == value then
      return true
    end
  end
  return false
end

return includes
