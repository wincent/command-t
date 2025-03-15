-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local function includes(t, value)
  for _, candidate in ipairs(t) do
    if candidate == value then
      return true
    end
  end
  return false
end

return includes
