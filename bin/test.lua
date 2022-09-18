#!/usr/bin/env luajit

-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

if #arg == 0 then
  -- We use a wrapper script because Lua doesn't provide any built-in APIs for
  -- reading directories.
  print('test.lua: please execute using the `test` wrapper script')
  os.exit(1)
end

local pwd = os.getenv('PWD')
local bin_directory = debug.getinfo(1).source:match('@?(.*/)')
assert(bin_directory == 'bin/')
local lua_directory = pwd .. '/lua/'

package.path = lua_directory .. '?.lua;' .. package.path
package.path = lua_directory .. '?/init.lua;' .. package.path

local is_list = require('wincent.commandt.private.is_list')
local is_table = require('wincent.commandt.private.is_table')

local contexts = {}
local current_context = nil
local current_test = nil

_G.context = function(description, callback)
  if current_test then
    error('cannot nest a `context()` inside an `it()`')
  end
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

_G.describe = function(description, callback)
  if current_test then
    error('cannot nest a `describe()` inside an `it()`')
  end
  return _G.context(description, callback)
end

_G.before = function(callback)
  if current_test then
    error('cannot nest a `before()` inside an `it()`')
  end
  assert(current_context)
  table.insert(current_context.before, callback)
end

_G.after = function(callback)
  if current_test then
    error('cannot nest an `after()` inside an `it()`')
  end
  assert(current_context)
  table.insert(current_context.after, callback)
end

_G.it = function(description, callback)
  if current_test then
    error('cannot nest an `it()` inside another `it()`')
  end
  assert(current_context)
  local test = {
    kind = 'test',
    description = description,
    callback = callback,
  }
  table.insert(current_context.children, test)
end

_G.pending = function(description)
  if current_test == nil then
    error('`pending` can only be used inside an `it()`')
  end
  -- TODO: could potentially use this to mark context/describe blocks as pending
  -- too if `current_context` is set
  error({
    kind = 'skipped',
    description = description,
  })
end

local equal = nil

equal = function(a, b)
  if type(a) == 'table' and type(b) == 'table' then
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

local inspect = nil

inspect = function(value, indent)
  local prefix = (' '):rep(indent)
  if type(value) == 'string' then
    return prefix .. "'" .. value:gsub('\\', '\\\\'):gsub("'", "\\'") .. "'"
  elseif type(value) == 'table' then
    if is_list(value) then
      if #value == 0 then
        return prefix .. '{}'
      else
        local output = prefix .. '{\n'
        for _, v in ipairs(value) do
          output = output .. inspect(v, indent + 2) .. ',\n'
        end
        output = output .. prefix .. '}'
        return output
      end
    else
      local output = prefix .. '{\n'
      output = output .. prefix .. '}'
      for k, v in pairs(value) do
        local trimmed = inspect(v, indent + 2):gsub('^%s+', '')
        output = output .. '[' .. inspect(k, 0) .. '] = ' .. trimmed .. ',\n'
      end
      return output
    end
  else
    return prefix .. tostring(value)
  end
end

_G.expect = function(value)
  return {
    to_be = function(other)
      if value ~= other then
        print('\nExpected:\n\n' .. inspect(other, 2) .. '\n')
        print('Actual:\n\n' .. inspect(value, 2) .. '\n')
        inspect(value)
        error('not ==', 2)
      end
    end,

    to_equal = function(other)
      if not equal(value, other) then
        print('\nExpected:\n\n' .. inspect(other, 2) .. '\n')
        print('Actual:\n\n' .. inspect(value, 2) .. '\n')
        error('not equal', 2)
      end
    end,

    -- `not` matchers are duplicated for now; if we start to have lots of them,
    -- will refactor.
    not_to_be = function(other)
      if value == other then
        print('\nExpected (not):\n\n' .. inspect(other, 2) .. '\n')
        print('Actual:\n\n' .. inspect(value, 2) .. '\n')
        error('==', 2)
      end
    end,

    not_to_equal = function(other)
      if equal(value, other) then
        print('\nExpected (not):\n\n' .. inspect(other, 2) .. '\n')
        print('Actual:\n\n' .. inspect(value, 2) .. '\n')
        error('equal', 2)
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

-- (Bold) yellow.
local yellow = function(str)
  return '\027[1;33m' .. str .. '\027[0m'
end

local yellow_bg = function(str)
  return '\027[43m\027[30m' .. str .. '\027[0m'
end

local INDENT = '  '

local stats = {
  passed = 0,
  failed = 0,
  skipped = 0,
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
      for _ = 1, #runnable.before do
        table.remove(setup)
      end
      for _ = 1, #runnable.after do
        table.remove(teardown, 1)
      end
    end
  elseif runnable.kind == 'test' then
    for _, callback in ipairs(setup) do
      callback()
    end
    current_test = runnable
    local status, err = pcall(runnable.callback)
    if status then
      stats.passed = stats.passed + 1
      print(indent .. green_bg(' PASS ') .. ' ' .. runnable.description)
    elseif type(err) == 'table' and err.kind == 'skipped' then
      stats.skipped = stats.skipped + 1
      local description = runnable.description
      if err.description then
        description = description .. ' (' .. err.description .. ')'
      end
      print(indent .. yellow_bg(' SKIP ') .. ' ' .. description)
    else
      stats.failed = stats.failed + 1
      print(indent .. red_bg(' FAIL ') .. ' ' .. err)
    end
    current_test = nil
    for _, callback in ipairs(teardown) do
      callback()
    end
  else
    error('run(): unrecognized runnable.kind ' .. runnable.kind)
  end
end

local time = require('wincent.commandt.private.time')

local wall = time.wall(function()
  for _, runnable in ipairs(contexts) do
    run(runnable, '')
  end
end)

local format_passed = function(passed)
  if passed > 0 then
    return green(passed .. ' passed')
  else
    return '0 passed'
  end
end

local format_failed = function(failed)
  if failed > 0 then
    return red(failed .. ' failed')
  else
    return '0 failed'
  end
end

local format_skipped = function(skipped)
  if skipped > 0 then
    return yellow(skipped .. ' skipped')
  else
    return '0 skipped'
  end
end

print(
  '\n'
    .. format_passed(stats.passed)
    .. ', '
    .. format_failed(stats.failed)
    .. ', '
    .. format_skipped(stats.skipped)
    .. ', '
    .. (stats.passed + stats.failed + stats.skipped)
    .. ' total in '
    .. string.format('%.6fs', wall)
)
