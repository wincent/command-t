-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local M = {}

M.scanner = function(user_command, drop, max_files)
  local scanner_new_exec = require('wincent.commandt.private.lib.scanner_new_exec')
  local scanner = scanner_new_exec(user_command, drop, max_files)
  return scanner
end

return M
