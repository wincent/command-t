-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local git = {}

git.scanner = function(dir, options)
  local lib = require('wincent.commandt.private.lib')
  local command = 'git ls-files --exclude-standard --cached -z'
  if options.submodules then
    command = command .. ' --recurse-submodules'
  elseif options.untracked then
    command = command .. ' --untracked'
  end
  if dir ~= '' then
    command = command .. ' -- ' .. dir
  end
  print(vim.inspect(command))
  local scanner = lib.scanner_new_command(command)
  return scanner
end

return git
