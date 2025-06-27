-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Infers which directory a scanner should operate in.
---
--- - If passed a non-blank `directory`, returns that.
--- - Otherwise, based on the `'traverse'` setting, either returns the nearest
---   SCM root directory, or the current working directory.
---
--- @param directory string | nil
--- @return string
local function get_directory(directory)
  if directory and vim.trim(directory) ~= '' then
    return directory
  else
    local options = require('wincent.commandt.private.options'):get()
    local find_root = require('wincent.commandt.private.find_root')
    if options.traverse == 'file' then
      local file = vim.fn.expand('%:p:h') -- If no current file, returns current dir.
      return find_root(file, options.root_markers)
    elseif options.traverse == 'pwd' then
      return find_root(vim.fn.getcwd(), options.root_markers)
    else
      return vim.fn.getcwd()
    end
  end
end

return get_directory
