-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local directory_stack = require('wincent.commandt.private.directory_stack')

--- Push a directory onto the stack.
---
--- @param directory string
--- @return nil
local function pushd(directory)
  table.insert(directory_stack, vim.uv.cwd())
  vim.fn.chdir(directory)
end

return pushd
