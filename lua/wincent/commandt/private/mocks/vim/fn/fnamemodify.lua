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

  vim.fn.fnamemodify = function(name, _modifier)
    return name
  end
end

return M
