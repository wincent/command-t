-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Returns `true` if `numberish` is an integer.
---
--- @param numberish any
--- @return boolean
local function is_integer(numberish)
  return type(numberish) == 'number' and math.floor(numberish) == numberish
end

return is_integer
