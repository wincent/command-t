-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Common `on_directory` implementation that infers the appropriate directory
--- if none is explicitly provided.
---
--- @param directory string | nil
--- @return string
local function on_directory(directory)
  if directory == '' or directory == nil then
    local get_directory = require('wincent.commandt.private.get_directory')
    return get_directory()
  else
    return directory
  end
end

return on_directory
