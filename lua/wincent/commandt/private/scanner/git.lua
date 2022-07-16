-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local git = {}

git.scanner = function(dir)
  local lib = require('wincent.commandt.private.lib')
  -- TODO: complexify the command here (account for submodules etc)
  local command = 'git ls-files --exclude-standard -cz'
  local scanner = lib.scanner_new_command(command)
  return scanner
end

return git
