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
local lua = pwd .. '/' .. bin_directory .. '../lua/'

package.path = lua .. '?.lua;' .. package.path
package.path = lua .. '?/init.lua;' .. package.path

local contexts = {}
local current_context = nil

_G.describe = function(description, callback)
  assert(current_context)
  local context = {
    kind = 'context',
    description = description,
    children = {},
  }
  local previous_context = current_context
  table.insert(previous_context.children, context)
  current_context = context
  callback()
  current_context = previous_context
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

_G.expect = function(value)
  return {
    to_equal = function(other)
      -- TODO: don't actually use `assert()` for this.
      -- TODO: or if we do use it, use debug.getinfo() to print right file info
      assert(value == other)
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

  local context = {kind = 'context', description = name, children = {}}
  table.insert(contexts, context)
  current_context = context
  require(name)
  current_context = nil
end

local run = nil

-- TODO print contexts, indentation etc
run = function(runnable)
  if runnable.kind == 'context' then
    for _, child in ipairs(runnable.children) do
      run(child)
    end
  elseif runnable.kind == 'test' then
    local status, err = pcall(runnable.callback)
    if status then
      print('PASS: ' .. runnable.description)
    else
      print('FAIL: ' .. err)
    end
  else
    error('run(): unrecognized runnable.kind ' .. runnable.kind)
  end
end

for _, runnable in ipairs(contexts) do
  run(runnable)
end
