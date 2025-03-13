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

  vim.fn.strwidth = function(str)
    -- (Loosely) count display cells required to display `str`.
    local cells = 0

    -- %z\1-\127 = ASCII character (from 0/NUL through decimal 127).
    -- \194-\244 = First byte of multi-byte UTF-8 codepoint.
    -- \128-\191 = Second and subsequent bytes of multi-byte UTF-8 codepoints.
    for codepoint in str.gmatch(str, '[%z\1-\127\194-\244][\128-\191]*') do
      local len = string.len(codepoint)
      if len == 1 then
        cells = cells + 1
      elseif len == 2 then
        -- Hack: assume 2-byte codepoints are single-width.
        cells = cells + 1
      else
        -- Hack: assume 3-byte and 4-byte codepoints are double-width.
        cells = cells + 2
      end
    end

    return cells
  end
end

return M
