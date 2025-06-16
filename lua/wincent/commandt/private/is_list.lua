-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Returns `true` if `value` is a list-like table.
---
--- @param value any
--- @return boolean
local function is_list(value)
  if type(value) ~= 'table' then
    return false
  elseif #value > 0 then
    return true
  else
    for _k, _v in pairs(value) do
      return false
    end
  end
  return true
end

return is_list
