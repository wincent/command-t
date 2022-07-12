#!/usr/bin/env luajit

-- SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require'ffi'

local pwd = os.getenv('PWD')
local benchmarks_directory  = debug.getinfo(1).source:match('@?(.*/)')
local lua = pwd .. '/' .. benchmarks_directory .. '../../lua/'

package.path = lua .. '?.lua;' .. package.path
package.path = lua .. '?/init.lua;' .. package.path
package.path = pwd .. '/' .. benchmarks_directory .. '../../data/?.lua;' .. package.path

local commandt = require'wincent.commandt'

-- Using a Lua module for benchmark data so that we don't need to pull in a JSON
-- or YAML dependency.
local data = require'wincent.benchmark'

local lib = require'wincent.commandt.lib'

commandt.epoch() -- Force eager loading of C library.

local options = {
  -- TODO may want to put something in here (like a high limit) to make this an
  -- apples-to-apples comparison
  -- although in reality, no client will (or should) ever ask for more than,
  -- say, 100 matches...
}

for i = 1, tonumber(os.getenv('TIMES') or 20) do
  for _, mode in ipairs({'Rehearsal', 'Final----'}) do
    print('\n' .. mode .. '------------      total         wall')

    for _, config in ipairs(data.tests) do
      local scanner = lib.scanner_new_copy(config.paths)
      local matcher = lib.commandt_matcher_new(scanner, options)

      local start_cpu = os.clock()
      local start_wall_s, start_wall_us = commandt.epoch()

      for j = 1, config.times do
        for _, query in ipairs(config.queries) do
          local input = ''
          for letter in query:gmatch('.') do
            input = input .. letter
            local results = lib.commandt_matcher_run(matcher, input)
            for k = 0, results.count - 1 do
              local str = results.matches[k]
              ffi.string(str.contents, str.length) -- Neovim would do something here...
            end
          end
        end
      end

      local end_cpu = os.clock()
      local end_wall_s, end_wall_us = commandt.epoch()
      local wall_delta = (function()
        if end_wall_us >= start_wall_s then
          end_wall_us = end_wall_us + 1000000
          end_wall_s = end_wall_s - 1
        end
        return (end_wall_s - start_wall_s) + (end_wall_us - start_wall_us) / 1000000
      end)()

      print(string.format('%-22s  %.6f   (%.6f)', config.name, end_cpu - start_cpu, wall_delta))
    end
  end
end
