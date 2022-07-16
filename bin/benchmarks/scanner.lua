#!/usr/bin/env luajit

-- SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local pwd = os.getenv('PWD')
local lua_directory = pwd .. '/' .. debug.getinfo(1).source:match('@?(.*/)') .. '../../lua'

package.path = lua_directory .. '/?.lua;' .. package.path
package.path = lua_directory .. '/?/init.lua;' .. package.path

local benchmark = require('wincent.commandt.private.benchmark')

benchmark({
  config = 'wincent.commandt.benchmark.configs.scanner',

  log = 'wincent.commandt.benchmark.logs.scanner',

  setup = function(config)
    local scanner = require(config.source)
    if scanner.name == 'watchman' then
      -- TODO: don't hardcode this, obviously...
      scanner.set_sockname('/opt/homebrew/var/run/watchman/wincent-state/sock')
    end
    return scanner
  end,

  skip = function(config)
    return config.skip_in_ci and os.getenv('CI')
  end,

  run = function(config, setup)
    local scanner = setup.scanner(pwd) -- For now, only Watchman wants pwd.
    for i = 1, scanner.count do
      ffi.string(scanner.candidates[i - 1].contents)
    end
  end,
})
