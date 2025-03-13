-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local len = require('wincent.commandt.private.len')

-- Temporary wrapper to give us compatibility between Neovim v0.10.4 and
-- more recent nightlies; see: https://github.com/wincent/command-t/issues/434
--
-- `:help str_byteindex` in v0.10.4:
--
--     vim.str_byteindex({str}, {index}, {use_utf16})           *vim.str_byteindex()*
--         Convert UTF-32 or UTF-16 {index} to byte index. If {use_utf16} is not
--         supplied, it defaults to false (use UTF-32). Returns the byte index.
--
--         Invalid UTF-8 and NUL is treated like in |vim.str_utfindex()|. An {index}
--         in the middle of a UTF-16 sequence is rounded upwards to the end of that
--         sequence.
--
--         Parameters: ~
--           • {str}        (`string`)
--           • {index}      (`integer`)
--           • {use_utf16}  (`boolean?`)
--
-- `:help str_byteindex` in nightly:
--
--                                                              *vim.str_byteindex()*
--     vim.str_byteindex({s}, {encoding}, {index}, {strict_indexing})
--         Convert UTF-32, UTF-16 or UTF-8 {index} to byte index. If
--         {strict_indexing} is false then then an out of range index will return
--         byte length instead of throwing an error.
--
--         Invalid UTF-8 and NUL is treated like in |vim.str_utfindex()|. An {index}
--         in the middle of a UTF-16 sequence is rounded upwards to the end of that
--         sequence.
--
--         Parameters: ~
--           • {s}                (`string`)
--           • {encoding}         (`"utf-8"|"utf-16"|"utf-32"`)
--           • {index}            (`integer`)
--           • {strict_indexing}  (`boolean?`) default: true
--
--         Return: ~
--             (`integer`)

local function str_byteindex(str, encoding, start_char, strict_indexing)
  local success, result = pcall(function()
    -- Nightly.
    return vim.str_byteindex(str, encoding, start_char, strict_indexing)
  end)
  if success then
    return result
  end

  -- v0.10.4
  return vim.str_byteindex(str, start_char, false)
end

-- Unicode-aware `sub` implementation.
--
-- Like Lua's `string.sub()`, the `start_char` and (optional) `end_char`
-- indices are 1-based (and inclusive/closed).
--
local function sub(str, start_char, end_char)
  -- Negative numbers count backwards from back of string.
  if start_char < 0 or (end_char ~= nil and end_char < 0) then
    local length = len(str)
    if start_char < 0 then
      start_char = math.max(1, length + start_char + 1)
    end
    if end_char ~= nil and end_char < 0 then
      end_char = math.max(1, length + end_char + 1)
    end
  end

  -- Convert 1-based indices to 0-based ones.
  local start_byte = str_byteindex(str, 'utf-32', start_char - 1, false)
  local end_byte = end_char and str_byteindex(str, 'utf-32', end_char, false)

  -- Convert 0-based indices back to 1-based ones.
  return str:sub(start_byte + 1, end_char and end_byte)
end

return sub
