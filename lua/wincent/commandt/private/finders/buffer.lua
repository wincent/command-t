-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

-- TODO: eventually this will become a pure-C finder; for now we're just demoing
-- the `command` scanner
-- TODO: remember cached directories
return function()
  local lib = require('wincent.commandt.private.lib')
  local finder = {}
  local options = {}
  -- TODO: make `dir` actually do something here
  finder.scanner = require('wincent.commandt.private.scanners.buffer').scanner()
  finder.matcher = lib.commandt_matcher_new(finder.scanner, options)
  finder.run = function(query)
    local results = lib.commandt_matcher_run(finder.matcher, query)
    local strings = {}
    for i = 0, results.count - 1 do
      local str = results.matches[i]
      table.insert(strings, ffi.string(str.contents, str.length))
    end
    return strings
  end
  finder.select = function(item)
    -- TODO: something more sophisticated here
    vim.cmd('edit ' .. vim.fn.fnameescape(item))
  end
  return finder
end
