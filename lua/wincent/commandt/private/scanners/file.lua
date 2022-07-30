-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local file = {}

file.scanner = function(directory)
  local lib = require('wincent.commandt.private.lib')
  -- TODO: support max depth, dot directory filter etc
  local scanner = lib.file_scanner(directory)
  return scanner
end

return file
