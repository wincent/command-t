#!/usr/bin/env luajit

-- SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local pwd = os.getenv('PWD')
local benchmarks_directory  = debug.getinfo(1).source:match('@?(.*/)')
local lua = pwd .. '/' .. benchmarks_directory .. '../../lua/'

package.path = lua .. '?.lua;' .. package.path
package.path = lua .. '?/init.lua;' .. package.path

-- Note, may need to modify package.cpath too.
local commandt = require'wincent.commandt'

-- TODO want to print something like
--  $user-cpu-time $system-cpu-time ($wall-clock-time) -- rehearsal
--  $user-cpu-time $system-cpu-time ($wall-clock-time) -- actual

local start_cpu = os.clock()
local start_wall_s, start_wall_us = commandt.epoch()

local s = 0
for i = 1, 100000 do
  s = s + i
end

local end_cpu = os.clock()
local end_wall_s, end_wall_us = commandt.epoch()

local wall_delta = (function ()
  if end_wall_us >= start_wall_s then
    end_wall_us = end_wall_us + 1000000
    end_wall_s = end_wall_s - 1
  end
  return (end_wall_s - start_wall_s) + (end_wall_us - start_wall_us) / 1000000
end)()

print(string.format("elapsed (CPU): %.6f", end_cpu - start_cpu))
print(string.format("elapsed (wall): %.6f", wall_delta))
