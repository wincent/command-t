-- SPDX-FileCopyrightText: Copyright 2023-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Walks upwards through the filesystem from `starting_directory` looking for a
--- source control or project root as indicated by the presence of one of the
--- marker files or directories from the `root_markers` list.
---
--- Returns the root, if found; otherwise, returns the `starting_directory`.
---
--- @param starting_directory string
--- @param root_markers string[]
--- @return string
local function find_root(starting_directory, root_markers)
  -- Make absolute.
  starting_directory = vim.fn.fnamemodify(starting_directory, ':p')

  -- If it's a directory, :p will add a trailing slash, which we must strip.
  starting_directory = starting_directory:gsub('(.-)/$', '%1')

  local next_path = starting_directory
  local attempts = 0
  while attempts < 100 do
    attempts = attempts + 1
    for _, marker in ipairs(root_markers) do
      local candidate = next_path .. '/' .. marker
      if vim.fn.isdirectory(candidate) == 1 or vim.fn.filereadable(candidate) == 1 then
        return next_path
      end
    end
    next_path = vim.fs.normalize(vim.fs.joinpath(next_path, '..'))
  end

  -- Found nothing.
  return starting_directory
end

return find_root
