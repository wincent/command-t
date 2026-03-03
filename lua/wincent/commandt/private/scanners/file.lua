-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local M = {}

M.scanner = function(directory, max_files)
  local file_scanner = require('wincent.commandt.private.lib.file_scanner')
  -- TODO: support dot directory filter etc
  local scanner = file_scanner(directory, max_files)
  return scanner
end

return M
