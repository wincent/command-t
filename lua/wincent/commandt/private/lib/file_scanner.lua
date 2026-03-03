-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local c = require('wincent.commandt.private.lib.c')

local function file_scanner(directory, max_files)
  local scanner = c.commandt_file_scanner(directory, max_files or 0)
  ffi.gc(scanner, c.commandt_scanner_free)
  return scanner
end

return file_scanner
