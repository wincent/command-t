-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Unicode-aware `sub` implementation.
local function sub(str, start_char, end_char)
  local start_byte = vim.str_byteindex(str, 'utf-32', start_char, false)
  local end_byte = end_char and vim.str_byteindex(str, 'utf-32', end_char, false)
  return str:sub(start_byte, end_byte)
end

return sub
