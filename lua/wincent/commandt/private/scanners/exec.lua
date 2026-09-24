-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local M = {}

-- Blocking wrapper around async scanner (used in benchmarks and tests only).
M.scanner = function(user_command, drop, max_files)
  local c = require('wincent.commandt.private.lib.c')
  local scanner_new_exec_async = require('wincent.commandt.private.lib.scanner_new_exec_async')
  local scanner = scanner_new_exec_async(user_command, drop, max_files)
  c.commandt_scanner_wait(scanner)
  return scanner
end

return M
