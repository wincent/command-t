-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local find = {}

find.scanner = function(dir)
  local lib = require('wincent.commandt.private.lib')
  -- TODO: support max depth, dot directory filter etc
  local command = 'find -L . -type f -print0'
  -- Note: will need to teach scanner to drop 2 chars ("./") from front of each
  local scanner = lib.scanner_new_command(command)
  return scanner
end

return find
