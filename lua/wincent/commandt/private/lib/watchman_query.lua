-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local c = require('wincent.commandt.private.lib.c')

local function watchman_query(root, relative_root, socket)
  local raw = c.commandt_watchman_query(root, relative_root, socket)
  local result = {
    error = raw['error'] ~= nil and ffi.string(raw['error']) or nil,
    raw = raw, -- So caller can access and pass through cdata to matcher.
  }
  ffi.gc(raw, c.commandt_watchman_query_free)
  return result
end

return watchman_query
