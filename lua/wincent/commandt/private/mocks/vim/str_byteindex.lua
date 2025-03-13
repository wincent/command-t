-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local M = {}

function M.setup()
  if _G.vim == nil then
    _G.vim = {}
  end

  vim.str_byteindex = function(str, _encoding, start_char, _strict_indexing)
    -- (Loosely) count bytes before codepoint at `start_char`.
    local bytes = 0
    local codepoints = 0

    -- %z\1-\127 = ASCII character (from 0/NUL through decimal 127).
    -- \194-\244 = First byte of multi-byte UTF-8 codepoint.
    -- \128-\191 = Second and subsequent bytes of multi-byte UTF-8 codepoints.
    for codepoint in str.gmatch(str, '[%z\1-\127\194-\244][\128-\191]*') do
      if codepoints < start_char then
        bytes = bytes + string.len(codepoint)
        codepoints = codepoints + 1
      else
        break
      end
    end
    return bytes
  end
end

return M
