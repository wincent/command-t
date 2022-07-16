-- SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local buffer = {}

-- Returns the list of paths currently loaded into buffers.
buffer.get = function()
  local handles = vim.api.nvim_list_bufs()
  local paths = {}
  for _, handle in ipairs(handles) do
    if vim.api.nvim_buf_is_loaded(handle) then
      local name = vim.api.nvim_buf_get_name(handle)
      if name ~= '' then
        local relative = vim.fn.fnamemodify(name, ':~:.')
        table.insert(paths, relative)
      end
    end
  end
  return paths
end

buffer.scanner = function()
  local lib = require('wincent.commandt.private.lib')
  local scanner = lib.scanner_new_copy(buffer.get())
  return scanner
end

return buffer
