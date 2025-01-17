-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local M = {}

function M.setup()
  if _G.vim == nil then
    _G.vim = {}
  end

  vim.inspect = function(value)
    return '<inspect:' .. type(value) .. '>'
  end
end

return M
