-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local watchman = {}

local sockname = nil

-- TODO: figure out when to clean this up
local socket = nil

-- Run `watchman get-sockname` to get current socket name; `watchman` will spawn
-- in response to this command if it is not already running.
--
-- See: https://facebook.github.io/watchman/docs/cmd/get-sockname.html
local get_sockname = function()
  if sockname == nil then
    if vim.fn.executable('watchman') == 1 then
      local output = vim.fn.systemlist('watchman get-sockname')
      local decoded = vim.fn.json_decode(output)
      if decoded['error'] then
        error(
          'wincent.commandt.scanners.watchman.get_sockname(): watchman get-sockname error = '
            .. tostring(decoded['error'])
        )
      else
        sockname = decoded['sockname']
      end
    else
      error('wincent.commandt.scanners.watchman.get_sockname(): no watchman executable')
    end
  end
  return sockname
end

local get_socket = function()
  if socket == nil then
    local name = get_sockname()
    if name == nil then
      error('wincent.commandt.scanners.watchman.get_socket(): no sockname')
    end
    local lib = require('wincent.commandt.private.lib')
    socket = lib.commandt_watchman_connect(name)
  end
  return socket
end

-- Internal: Used by the benchmark suite so that we can identify this scanner
-- from among others.
watchman.name = 'watchman'

-- Internal: Used by the benchmark suite so that we can avoid calling `vim` functions
-- inside `get_sockname()` from our pure-C benchmark harness.
watchman.set_sockname = function(name)
  sockname = name
end

-- Equivalent to:
--
--    watchman -j <<-JSON
--      ["query", "/path/to/root", {
--        "expression": ["type", "f"],
--        "fields": ["name"],
--        "relative_root": "some/relative/path"
--      }]
--    JSON
--
-- If `relative_root` is `nil`, it will be omitted from the query.
--
local query = function(root, relative_root)
  local lib = require('wincent.commandt.private.lib')

  return lib.commandt_watchman_query(root, relative_root, get_socket())
end

-- Equivalent to `watchman watch-project $root`.
--
-- Returns a table with `watch` and `relative_path` properties. `relative_path`
-- my be `nil`.
local watch_project = function(root)
  local lib = require('wincent.commandt.private.lib')
  return lib.commandt_watchman_watch_project(root, get_socket())
end

-- BUG: We leak this forever, but I want its lifetime to be bonded to that of
-- the scanner object
local result = nil

watchman.scanner = function(dir)
  local lib = require('wincent.commandt.private.lib')
  local project = watch_project(dir)
  -- Result needs to persist until scanner is garbage collected.
  -- TODO: figure out the right way to do that...
  result = query(project.watch, project.relative_path)
  local scanner = lib.scanner_new_str(result.files, result.count)
  return scanner
end

return watchman
