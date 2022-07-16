-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local path = {}

function endswith(str, letter)
  return #str > 0 and str:sub(#str, #str) == letter
end

function startswith(str, letter)
  return #str > 0 and str:sub(1, 1) == letter
end

local Path = {}

local mt = {
  __add = function(a, b)
    local b_path = Path.new(b)

    local components = a:components()

    for i, component in ipairs(b_path:components()) do
      if component ~= '/' then
        table.insert(components, component)
      end
    end

    return Path.join(components)
  end,

  __eq = function(a, b)
    return tostring(a) == tostring(b)
  end,

  __index = Path,

  __tostring = function(p)
    return p.__contents
  end,
}

function Path.new(contents)
  local p = {
    __contents = contents ~= nil and tostring(contents) or '',
  }
  setmetatable(p, mt)
  return p
end

function Path.join(components)
  local raw = ''
  for i, component in ipairs(components) do
    if i == 1 then
      raw = component
    elseif raw == '/' then
      raw = raw .. component
    else
      raw = raw .. '/' .. component
    end
  end
  return Path.new(raw)
end

function Path.pwd()
  local pwd = os.getenv('PWD')
  assert(startswith(pwd, '/'))
  return Path.new(pwd)
end

function Path:is_absolute()
  return startswith(tostring(self), '/')
end

function Path:is_relative()
  return not startswith(tostring(self), '/')
end

-- '/'         → {'/'}
-- '/foo/bar'  → {'/', 'foo', 'bar'}
-- '/foo/bar/' → {'/', 'foo', 'bar'}
-- 'foo/bar'   → {'foo', 'bar'}
-- 'foo//bar'  → {'foo', 'bar'}
-- 'foo///bar' → {'foo', 'bar'}
-- './foo'     → {'.', 'foo'}
-- 'foo'       → {'foo'}
function Path:components()
  local components = {}

  if self:is_absolute() then
    table.insert(components, '/')
  end

  -- Append a trailing '/' before calling `gmatch()` to enable us to use a
  -- simpler pattern; via: https://stackoverflow.com/a/19908161/2103996
  for component in (tostring(self) .. '/'):gmatch('([^/]*)/') do
    if component ~= '' then
      table.insert(components, component)
    end
  end

  return components
end

-- Simplifies a path by resolving '..' and '.' path components in non-leading
-- positions (matching the behavior of NodeJS's `path` module).
--
-- Returns a string, because everywhere I've ever wanted to pass a normalized
-- path has wanted a string.
function Path:normalize()
  local components = self:components()
  local index = 1
  while true do
    local component = components[index]
    if component == nil then
      break
    elseif component == '..' then
      if index == 1 or components[index - 1] == '..' then
        index = index + 1
      else
        table.remove(components, index)
        table.remove(components, index - 1)
        index = index - 1
      end
    elseif component == '.' then
      if #components > 1 then
        table.remove(components, index)
      else
        break
      end
    else
      index = index + 1
    end
  end
  if #components > 0 then
    return tostring(Path.join(components))
  else
    return tostring(Path.new('.'))
  end
end

function Path:prepend_to_package_path()
  -- TODO: could add a check for duplicates alreayd in the package.path here
  local addition = self:normalize()
  package.path = addition .. '/?.lua;' .. addition .. '/?/init.lua;' .. package.path
end

path.Path = Path

-- Returns the path of the caller's file.
path.caller = function()
  local source = debug.getinfo(2).source
  if startswith(source, '@') then
    return Path.new(source:sub(2, -1))
  else
    return Path.new(source)
  end
end

return path
