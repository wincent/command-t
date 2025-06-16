-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local sub = require('wincent.commandt.private.sub')

--- Attempts to return a suffix of `str` of size `length`, as measured in screen
--- cells. If `str` if overlength, and the final character that must be trimmed
--- to bring it down to the desired length is a double-cell one, the actual
--- returned link may be off (specifically, under) by 1 screen cell.
---
--- @param str string
--- @param length integer
--- @return string
local function str_suffix(str, length)
  if length < 1 then
    return ''
  end
  local trim = 0
  while vim.fn.strwidth(str) > length do
    -- For typical strings, we'll do at most one `sub()`. For the degenerate
    -- case with many multi-cell glyphs, we'll loop as many times as needed.
    str = sub(str, -(length - trim))
    trim = trim + 1
  end
  return str
end

return str_suffix
