-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

return function(directory, command, options, name)
  local lib = require('wincent.commandt.private.lib')
  local drop = 0
  local max_files = 0
  local get_max_files = options.finders[name].max_files
  if type(command) == 'function' then
    command, drop = command(directory, options)
  end
  if type(get_max_files) == 'number' then
    max_files = get_max_files
  elseif type(get_max_files) == 'function' then
    max_files = get_max_files(options) or 0
  end
  local finder = {}
  finder.scanner = require('wincent.commandt.private.scanners.command').scanner(command, drop, max_files)
  finder.matcher = lib.matcher_new(finder.scanner, options)
  finder.run = function(query)
    local results = lib.matcher_run(finder.matcher, query)
    local strings = {}
    for i = 0, results.match_count - 1 do
      local str = results.matches[i]
      table.insert(strings, ffi.string(str.contents, str.length))
    end
    return strings, results.candidate_count
  end
  finder.open = options.open
  return finder
end
