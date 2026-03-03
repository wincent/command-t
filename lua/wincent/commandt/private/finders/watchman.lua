-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

return function(directory, options)
  if directory == nil or directory == '' then
    directory = os.getenv('PWD')
  end
  local matcher_new = require('wincent.commandt.private.lib.matcher_new')
  local matcher_run = require('wincent.commandt.private.lib.matcher_run')
  local finder = {}
  finder.scanner = require('wincent.commandt.private.scanners.watchman').scanner(directory)
  finder.matcher = matcher_new(finder.scanner, options, { lines = vim.o.lines })
  finder.run = function(query)
    local results = matcher_run(finder.matcher, query)
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
