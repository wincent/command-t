-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local c = require('wincent.commandt.private.lib.c')

local function scanner_new_exec(command, drop, max_files)
  -- Note that the C-level function would ideally be named
  -- `commandt_scanner_new_exec()`, for consistency, but I am keeping the old
  -- name because I don't want to break userspace (ie. by forcing users to do a
  -- rebuild) just because I felt like refactoring some internal implementation
  -- details...
  local scanner = c.commandt_scanner_new_command(command, drop or 0, max_files or 0)
  ffi.gc(scanner, c.commandt_scanner_free)
  return scanner
end

return scanner_new_exec
