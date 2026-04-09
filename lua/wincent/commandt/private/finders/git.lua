-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local get_directory = require('wincent.commandt.get_directory')
local on_open = require('wincent.commandt.on_open')
local popd = require('wincent.commandt.popd')
local pushd = require('wincent.commandt.pushd')

local git = {
  command = function(directory, options)
    pushd(directory)
    local command = 'git ls-files --exclude-standard --cached -z'
    if options.scanners.git.submodules then
      command = command .. ' --recurse-submodules'
    elseif options.scanners.git.untracked then
      command = command .. ' --others'
    end
    command = command .. ' 2> /dev/null'
    local drop = 0
    return command, drop
  end,
  fallback = true,
  max_files = function(options)
    return options.scanners.git.max_files
  end,
  on_close = popd,
  on_directory = get_directory,
  open = on_open,
}

return git
