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
  return vim.fs.root(starting_directory, root_markers) or starting_directory
end

return find_root
