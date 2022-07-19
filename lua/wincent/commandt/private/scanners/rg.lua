-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local rg = {}

rg.scanner = function(dir)
  local lib = require('wincent.commandt.private.lib')
  local command = 'rg --files --null'
  local scanner = lib.scanner_new_command(command)
  return scanner
end

return rg
