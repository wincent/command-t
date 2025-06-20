-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

return function(directory, candidates, options)
  local lib = require('wincent.commandt.private.lib')
  local finder = {}
  local context = nil
  if type(candidates) == 'function' then
    local candidates_for_scanner, candidates_context = candidates(directory, options)
    context = candidates_context
    finder.scanner = require('wincent.commandt.private.scanners.list').scanner(candidates_for_scanner)
    finder.context = context
  elseif type(candidates) == 'table' then
    finder.scanner = require('wincent.commandt.private.scanners.list').scanner(candidates)
  else
    error('wincent.commandt.private.finders.list() expected function or table')
  end
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
  return finder, context
end
