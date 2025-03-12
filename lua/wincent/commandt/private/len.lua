-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Temporary wrapper to give us compatibility between Neovim v0.10.4 and
-- more recent nightlies; see: https://github.com/wincent/command-t/issues/434
--
-- `:help str_utfindex` in v0.10.4:
--
--     vim.str_utfindex({str}, {index})                          *vim.str_utfindex()*
--         Convert byte index to UTF-32 and UTF-16 indices. If {index} is not
--         supplied, the length of the string is used. All indices are zero-based.
--
--         Embedded NUL bytes are treated as terminating the string. Invalid UTF-8
--         bytes, and embedded surrogates are counted as one code point each. An
--         {index} in the middle of a UTF-8 sequence is rounded upwards to the end of
--         that sequence.
--
--         Parameters: ~
--           • {str}    (`string`)
--           • {index}  (`integer?`)
--
--         Return (multiple): ~
--             (`integer`) UTF-32 index
--             (`integer`) UTF-16 index
--
--
-- `:help str_utfindex` in nightly:
--
--                                                               *vim.str_utfindex()*
--     vim.str_utfindex({s}, {encoding}, {index}, {strict_indexing})
--         Convert byte index to UTF-32, UTF-16 or UTF-8 indices. If {index} is not
--         supplied, the length of the string is used. All indices are zero-based.
--
--         If {strict_indexing} is false then an out of range index will return
--         string length instead of throwing an error. Invalid UTF-8 bytes, and
--         embedded surrogates are counted as one code point each. An {index} in the
--         middle of a UTF-8 sequence is rounded upwards to the end of that sequence.
--
--         Parameters: ~
--           • {s}                (`string`)
--           • {encoding}         (`"utf-8"|"utf-16"|"utf-32"`)
--           • {index}            (`integer?`)
--           • {strict_indexing}  (`boolean?`) default: true
--
--         Return: ~
--             (`integer`)

local function str_utfindex(str, encoding, start_char, strict_indexing)
  local success, result = pcall(function()
    -- Nightly.
    return vim.str_utfindex(str, encoding, start_char, strict_indexing)
  end)
  if success then
    return result
  end

  -- v0.10.4
  return vim.str_utfindex(str, start_char)
end

-- Unicode-aware `len` implementation.
local function len(str)
  return str_utfindex(str, 'utf-32')
end

return len
