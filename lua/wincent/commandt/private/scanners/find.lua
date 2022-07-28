-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local find = {}

-- Note: because `dir` is going to be interpolated into a command invocation, it
-- should be shell escaped before calling this scanner.
find.scanner = function(dir)
  local drop = 0
  if dir == '' or dir == '.' then
    -- Drop 2 characters because `find` will prefix every result with "./",
    -- making it look like a dotfile.
    dir = '.'
    drop = 2
    -- TODO: decide what to do if somebody passes '..' or similar, because that
    -- will also make the results get filtered out as though they were dotfiles.
    -- I may end up needing to do some fancy, separate micromanagement of
    -- prefixes and let the matcher operate on paths without prefixes.
  end
  local lib = require('wincent.commandt.private.lib')
  -- TODO: support max depth, dot directory filter etc
  local command = 'find -L ' .. dir .. ' -type f -print0'
  local scanner = lib.scanner_new_command(command, drop)
  return scanner
end

return find
