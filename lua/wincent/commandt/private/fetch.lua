-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Fetch value `key` from table `t`, falling back to `default` if key is
--- missing.
---
--- @param t table A table from which to fetch a value
--- @param key string Key to be looked up in table
--- @param default any Default value to be returned if key is missing
--- @return any
local function fetch(t, key, default)
  if t[key] == nil then
    return default
  else
    return t[key]
  end
end

return fetch
