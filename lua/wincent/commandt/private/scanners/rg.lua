-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local rg = {}

-- Note: because `dir` is going to be interpolated into a command invocation, it
-- should be shell escaped before calling this scanner.
rg.scanner = function(dir)
  local drop = 0
  if dir == '.' then
    drop = 2
  end
  local lib = require('wincent.commandt.private.lib')
  local command = 'rg --files --null'
  if #dir > 0 then
    command = command .. ' ' .. dir
  end
  local scanner = lib.scanner_new_command(command, drop)
  return scanner
end

return rg
