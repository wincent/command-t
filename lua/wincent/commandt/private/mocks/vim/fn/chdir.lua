-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local M = {}

function M.setup()
  if _G.vim == nil then
    _G.vim = {}
  end
  if vim.fn == nil then
    vim.fn = {}
  end

  vim.fn.chdir = function(str)
    return nil
  end
end

return M
