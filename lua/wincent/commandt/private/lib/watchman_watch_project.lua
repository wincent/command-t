-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local c = require('wincent.commandt.private.lib.c')

local function watchman_watch_project(root, socket)
  local result = c.commandt_watchman_watch_project(root, socket)
  local project = {
    error = result['error'] ~= nil and ffi.string(result['error']) or nil,
    relative_path = result['relative_path'] ~= nil and ffi.string(result['relative_path']) or nil,
    watch = result['watch'] ~= nil and ffi.string(result['watch']) or nil,
  }
  c.commandt_watchman_watch_project_free(result)
  return project
end

return watchman_watch_project
