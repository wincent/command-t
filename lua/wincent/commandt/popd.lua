-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local directory_stack = require('wincent.commandt.private.directory_stack')

--- Pop a directory from the stack.
---
--- @return nil
local function popd()
  local directory = table.remove(directory_stack)
  if directory then
    vim.fn.chdir(directory)
  end
end

return popd
