-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local function relativize(directory, file)
  if directory ~= '' then
    return vim.fs.normalize(vim.fs.joinpath(directory, file))
  else
    return file
  end
end

return relativize
