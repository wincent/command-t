#!/usr/bin/env luajit

-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

if #arg == 0 then
  -- We use a wrapper script because Lua doesn't provide any built-in APIs for
  -- reading directories.
  print('test.lua: please execute using the test.sh wrapper script')
  os.exit(1)
end

local pwd = os.getenv('PWD')
local bin_directory  = debug.getinfo(1).source:match('@?(.*/)')
assert(bin_directory == 'bin/')
local lua = pwd .. '/lua/'

package.path = lua .. '?.lua;' .. package.path
package.path = lua .. '?/init.lua;' .. package.path

local contexts = {}
local current_context = nil

_G.context = function(description, callback)
  assert(current_context)
  local context = {
    kind = 'context',
    description = description,
    before = {},
    children = {},
    after = {},
  }
  local previous_context = current_context
  table.insert(previous_context.children, context)
  current_context = context
  callback()
  current_context = previous_context
end

_G.describe = _G.context

_G.before = function(callback)
  assert(current_context)
  table.insert(current_context.before, callback)
end

_G.after = function(callback)
  assert(current_context)
  table.insert(current_context.after, callback)
end

_G.it = function(description, callback)
  assert(current_context)
  local test = {
    kind = 'test',
    description = description,
    callback = callback,
  }
  table.insert(current_context.children, test)
end

local equal = nil

equal = function(a, b)
  if (type(a) == 'table' and type(b) == 'table') then
    if #a == #b then
      for k, v in pairs(a) do
        if not equal(v, b[k]) then
          return false
        end
      end
      return true
    end
  else
    return a == b
  end
end

_G.expect = function(value)
  return {
    to_equal = function(other)
      if not equal(value, other) then
        -- TODO: say how it was different
        error('not equal', 2)
      end
    end,
  }
end

for _, name in ipairs(arg) do
  -- Strip off leading 'lua/'.
  name, _ = name:gsub('^lua/', '')

  -- Strip off trailing '.lua' (or '/init.lua').
  name, _ = name:gsub('/init.lua$', '')
  name, _ = name:gsub('.lua$', '')

  -- Slashes to dots.
  name, _ = name:gsub('/', '.')

  local context = {
    kind = 'context',
    description = name,
    before = {},
    children = {},
    after = {},
  }
  table.insert(contexts, context)
  current_context = context
  require(name)
  current_context = nil
end

-- Just bold.
local bold = function(str)
  return '\027[1;37m' .. str .. '\027[0m'
end

-- (Bold) green.
local green = function(str)
  return '\027[1;32m' .. str .. '\027[0m'
end

local green_bg = function(str)
  return '\027[42m\027[30m' .. str .. '\027[0m'
end

-- (Bold) red.
local red = function(str)
  return '\027[1;31m' .. str .. '\027[0m'
end

local red_bg = function(str)
  return '\027[41m\027[30m' .. str .. '\027[0m'
end

local INDENT = '  '

local stats = {
  passed = 0,
  failed = 0,
}

local setup = {}
local teardown = {}

local run = nil

run = function(runnable, indent)
  if runnable.kind == 'context' then
    print(indent .. bold(runnable.description))
    for _, child in ipairs(runnable.children) do
      for _, callback in ipairs(runnable.before) do
        table.insert(setup, callback)
      end
      for _, callback in ipairs(runnable.after) do
        table.insert(teardown, 1, callback)
      end
      run(child, indent .. INDENT)
      for _ = 1, #(runnable.before) do
        table.remove(setup)
      end
      for _ = 1, #(runnable.after) do
        table.remove(teardown, 1)
      end
    end
  elseif runnable.kind == 'test' then
    for _, callback in ipairs(setup) do
      callback()
    end
    local status, err = pcall(runnable.callback)
    if status then
      stats.passed = stats.passed + 1
      print(indent .. green_bg(' PASS ') .. ': ' .. runnable.description)
    else
      stats.failed = stats.failed + 1
      print(indent .. red_bg(' FAIL ') .. ': ' .. err)
    end
    for _, callback in ipairs(teardown) do
      callback()
    end
  else
    error('run(): unrecognized runnable.kind ' .. runnable.kind)
  end
end

local commandt = require'wincent.commandt'

local start_wall_s, start_wall_us = commandt.epoch()

for _, runnable in ipairs(contexts) do
  run(runnable, '')
end

local end_wall_s, end_wall_us = commandt.epoch()

local delta = (function ()
  if end_wall_us >= start_wall_s then
    end_wall_us = end_wall_us + 1000000
    end_wall_s = end_wall_s - 1
  end
  return (end_wall_s - start_wall_s) + (end_wall_us - start_wall_us) / 1000000
end)()

local format_passed = function(passed)
  if passed > 0 then
    return bold(green(passed .. ' passed'))
  else
    return '0 passed'
  end
end

local format_failed = function(failed)
  if failed > 0 then
    return bold(red(failed .. ' failed'))
  else
    return '0 failed'
  end
end

local time = string.format('%.6fs', delta)

print(
  '\n' ..
  format_passed(stats.passed) .. ', ' ..
  format_failed(stats.failed) .. ', ' ..
  (stats.passed + stats.failed) .. ' total in ' ..
  time
)
