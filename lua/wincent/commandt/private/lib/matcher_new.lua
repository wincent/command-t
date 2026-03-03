-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local fetch = require('wincent.commandt.private.fetch')
local c = require('wincent.commandt.private.lib.c')
local processors = require('wincent.commandt.private.lib.processors')
local toboolean = require('wincent.commandt.private.toboolean')

-- For the first 8 cores, use 1 thread per core.
-- Beyond the first 8 cores, use 1 additional thread per 4 cores.
local default_thread_count = function()
  local count = processors()
  if count < 8 then
    return count
  else
    return 8 + math.floor((count - 8) / 4)
  end
end

local function matcher_new(scanner, options, context)
  local always_show_dot_files = fetch(options, 'always_show_dot_files', false)
  local ignore_case = fetch(options, 'ignore_case', true)
  local ignore_spaces = fetch(options, 'ignore_spaces', true)
  local height = fetch(options, 'height', 15)
  local limit = math.min(height, context and context.lines or 1000)
  local never_show_dot_files = fetch(options, 'never_show_dot_files', false)
  local smart_case = fetch(options, 'smart_case', true)
  local threads = fetch(options, 'threads', default_thread_count())
  if limit < 1 then
    error('limit must be > 0')
  end
  if type(ignore_case) == 'function' then
    ignore_case = toboolean(ignore_case())
  end
  if type(smart_case) == 'function' then
    smart_case = toboolean(smart_case())
  end
  local matcher = c.commandt_matcher_new(
    scanner,
    always_show_dot_files,
    ignore_case,
    ignore_spaces,
    limit,
    never_show_dot_files,
    smart_case,
    threads
  )
  ffi.gc(matcher, c.commandt_matcher_free)
  return matcher
end

return matcher_new
