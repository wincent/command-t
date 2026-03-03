-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local c = require('wincent.commandt.private.lib.c')

local function scanner_new_copy(candidates)
  local count = #candidates
  local scanner = c.commandt_scanner_new_copy(ffi.new('const char *[' .. count .. ']', candidates), count)
  ffi.gc(scanner, c.commandt_scanner_free)
  return scanner
end

return scanner_new_copy
