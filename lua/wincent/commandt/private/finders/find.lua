-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local on_directory = require('wincent.commandt.on_directory')
local on_open = require('wincent.commandt.on_open')
local popd = require('wincent.commandt.popd')
local pushd = require('wincent.commandt.pushd')

local find = {
  command = function(directory, _options)
    pushd(directory)
    local command = 'find -L . -type f -print0 2> /dev/null'
    local drop = 2 -- drop './'
    return command, drop
  end,
  fallback = true,
  max_files = function(options)
    return options.scanners.find.max_files
  end,
  on_close = popd,
  on_directory = on_directory,
  open = on_open,
}

return find
