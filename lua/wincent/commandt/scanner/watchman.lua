-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local watchman = {}

local sockname = nil

local socket = nil

local files = nil

watchman.get = function(force)
  -- TODO impl; note that we don't want this to return a list of (Lua) strings
  -- but rather a scanner handle
end

watchman.get_socket = function()
  if socket == nil then
    local name = watchman.get_sockname()
    if name == nil then
      error('wincent.commandt.scanner.watchman.get_socket(): no sockname')
    end
    local lib = require('wincent.commandt.lib')
    socket = lib.commandt_watchman_connect(name)
  end
  return socket
end

-- Run `watchman get-sockname` to get current socket name; `watchman` will spawn
-- in response to this command if it is not already running.
--
-- See: https://facebook.github.io/watchman/docs/cmd/get-sockname.html
watchman.get_sockname = function()
  if sockname == nil then
    if vim.fn.executable('watchman') == 1 then
      local output = vim.fn.systemlist('watchman get-sockname')
      local decoded = vim.fn.json_decode(output)
      if decoded['error'] then
        error('wincent.commandt.scanner.watchman.get_sockname(): watchman get-sockname error = ' .. tostring(decoded['error']))
      else
        sockname = decoded['sockname']
      end
    else
      error('wincent.commandt.scanner.watchman.get_sockname(): no watchman executable')
    end
  end
  return sockname
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
watchman.query = function(root, relative_root)
  local socket = watchman.get_socket() -- TODO: when to clean up?
  local lib = require('wincent.commandt.lib')

  -- To see this, run:
  --
  --     llvm --file nvim
  --     r
  --     :lua my_watch = require'wincent.commandt.scanner.watchman'.watch_project('/Users/wincent/code/command-t')
  --     :lua require'wincent.commandt.scanner.watchman'.query(my_watch['watch'])
  --
  return lib.commandt_watchman_query(root, relative_root, socket)
end

-- temporary function
watchman.scanner = function()
  local lib = require('wincent.commandt.lib')
  local project = watchman.watch_project('/Users/wincent/code/command-t')
  local result = watchman.query(project.watch, project.relative_root)
  local scanner = lib.scanner_new_str(result.files, result.count)
  return scanner
end

-- Equivalent to `watchman watch-project $root`.
--
-- Returns a table with `watch` and `relative_path` properties. `relative_path`
-- my be `nil`.
watchman.watch_project = function(root)
  local socket = watchman.get_socket() -- TODO: when to clean up?
  local lib = require('wincent.commandt.lib')

  -- To see this, run:
  --
  --     llvm --file nvim
  --     r
  --     :lua require'wincent.commandt.scanner.watchman'.watch_project('/Users/wincent/code/command-t')
  --
  return lib.commandt_watchman_watch_project(root, socket)
end

return watchman
