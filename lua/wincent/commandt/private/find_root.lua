-- SPDX-FileCopyrightText: Copyright 2023-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local find_root = nil

find_root = function(starting_directory, root_markers)
  local absolute_path = vim.fn.fnamemodify(starting_directory, ':p')
  while true do
    for _, marker in ipairs(root_markers) do
      -- If we get all the way to the root ('/'), don't use separator.
      local separator = vim.endswith(absolute_path, '/') and '' or '/'
      local candidate = absolute_path .. separator .. marker
      if vim.fn.isdirectory(candidate) == 1 or vim.fn.filereadable(candidate) == 1 then
        return absolute_path
      end
    end
    local next_path = vim.fn.simplify(absolute_path .. '/..')
    if string.find(absolute_path, '^/+$') then
      -- The `string.find()` is to make sure we bail if passed a bad path with
      -- multiple leading separators (eg. '////', which is the same as '/' but
      -- doesn't look like it).
      return vim.fn.getcwd()
    end
    absolute_path = next_path
  end
end

return find_root
