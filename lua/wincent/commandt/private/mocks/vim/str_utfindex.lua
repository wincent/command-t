-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local M = {}

function M.setup()
  if _G.vim == nil then
    _G.vim = {}
  end

  vim.str_utfindex = function(str, _encoding, start_char, _strict_indexing)
    if start_char == nil then
      -- (Loosely) count codepoints in entire string.
      local count = 0

      -- %z\1-\127 = ASCII character (from 0/NUL through decimal 127).
      -- \194-\244 = First byte of multi-byte UTF-8 codepoint.
      -- \128-\191 = Second and subsequent bytes of multi-byte UTF-8 codepoints.
      for _ in string.gmatch(str, '[%z\1-\127\194-\244][\128-\191]*') do
        count = count + 1
      end
      return count
    else
      error('unimplemented parameter type passed to vim.str_utfindex() stub')
    end
  end
end

return M
