-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local M = {}

function M.setup()
  if _G.vim == nil then
    _G.vim = {}
  end
  if vim.uv == nil then
    vim.uv = {}
  end

  vim.uv.cwd = function()
    return nil
  end
end

return M
