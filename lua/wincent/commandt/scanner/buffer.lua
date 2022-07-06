-- SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell. All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause

local buffer = {}

local buffers = nil

-- Returns the list of paths currently loaded into buffers.
--
-- Will return a cached value unless `force` is truthy (or there is no cached
-- value).
buffer.get = function(force)
  if buffers == nil or force then
    local handles = vim.api.nvim_list_bufs()
    local names = {}

    for _, handle in ipairs(handles) do
      if vim.api.nvim_buf_is_loaded(handle) then
        local name = vim.api.nvim_buf_get_name(handle)
        if name ~= '' then
          local hidden = vim.tbl_isempty(vim.fn.win_findbuf(handle))
          if not hidden then
            local relative = vim.fn.fnamemodify(name, ':~:.')
            table.insert(names, relative)
          end
        end
      end
    end

    if not vim.deep_equal(buffers, names) then
      -- Only overwrite cached value if it was actually different, preserving
      -- table identity.
      buffers = names
    end
  end

  return buffers
end

return buffer
