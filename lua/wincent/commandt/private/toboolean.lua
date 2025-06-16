-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Converts the supplied `value` to a boolean.
---
--- @param value any
--- @return boolean
local function toboolean(value)
  return not not value
end

return toboolean
