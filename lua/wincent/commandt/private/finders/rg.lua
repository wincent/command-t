-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local get_directory = require('wincent.commandt.get_directory')
local on_open = require('wincent.commandt.on_open')
local popd = require('wincent.commandt.popd')
local pushd = require('wincent.commandt.pushd')

local rg = {
  command = function(directory, _options)
    pushd(directory)
    local command = 'rg --files --follow --no-messages --null 2> /dev/null'
    local drop = 0
    return command, drop
  end,
  fallback = true,
  max_files = function(options)
    return options.scanners.rg.max_files
  end,
  on_close = popd,
  on_directory = get_directory,
  open = on_open,
}

return rg
