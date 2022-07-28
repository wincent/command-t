#!/usr/bin/env luajit

-- SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local pwd = os.getenv('PWD')
local lua_directory = pwd .. '/' .. debug.getinfo(1).source:match('@?(.*/)') .. '../../lua'

package.path = lua_directory .. '/?.lua;' .. package.path
package.path = lua_directory .. '/?/init.lua;' .. package.path

local benchmark = require('wincent.commandt.private.benchmark')
local lib = require('wincent.commandt.private.lib')

local options = {
  recurse = os.getenv('RECURSE') == nil or os.getenv('RECURSE') == '1',
  threads = tonumber(os.getenv('THREADS')),
  -- TODO may want to put something in here (like a high limit) to make this an
  -- apples-to-apples comparison
  -- although in reality, no client will (or should) ever ask for more than,
  -- say, 100 matches...
  -- TODO figure out why RECURSE makes a big difference in Lua port but almost
  -- none in Ruby one
}

benchmark({
  config = 'wincent.commandt.benchmark.configs.matcher',

  log = 'wincent.commandt.benchmark.logs.matcher',

  setup = function(config)
    local scanner = lib.scanner_new_copy(config.paths)
    local matcher = lib.matcher_new(scanner, options)
    return { matcher, scanner }
  end,

  run = function(config, setup)
    local matcher, _scanner = unpack(setup)
    for _, query in ipairs(config.queries) do
      local input = ''
      for letter in query:gmatch('.') do
        local matches = lib.matcher_run(matcher, input)
        for k = 0, matches.count - 1 do
          local str = matches.matches[k]
          ffi.string(str.contents, str.length)
        end
        input = input .. letter
      end
      local matches = lib.matcher_run(matcher, input)
      for k = 0, matches.count - 1 do
        local str = matches.matches[k]
        ffi.string(str.contents, str.length)
      end
    end
  end,
})
