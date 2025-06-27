-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local force_dot_files = require('wincent.commandt.private.options.force_dot_files')

-- Returns the list of paths currently loaded into buffers.
local buffer = {
  candidates = function(_directory, _options)
    local handles = vim.api.nvim_list_bufs()
    local paths = {}
    for _, handle in ipairs(handles) do
      if vim.api.nvim_buf_is_valid(handle) and vim.api.nvim_get_option_value('buflisted', { buf = handle }) then
        local name = vim.api.nvim_buf_get_name(handle)
        if name ~= '' then
          local relative = vim.fn.fnamemodify(name, ':~:.')
          table.insert(paths, relative)
        end
      end
    end
    return paths
  end,
  options = force_dot_files,
}

return buffer
