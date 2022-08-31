-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

-- TODO: remember cached directories
return function(directory, options)
  local finder = {}
  -- Use a thunk to avoid cost of fallback scanning until actually needed.
  finder.fallback = (
    (function(d, o)
      return function()
        finder.fallback = require('wincent.commandt.private.finders.file')(d ~= '' and d or '.', o)
        return finder.fallback
      end
    end)(directory, options)
  )
  if vim.startswith(directory, './') then
    directory = directory:sub(3, -1)
  end
  if directory ~= '' and directory ~= '.' then
    directory = vim.fn.shellescape(directory)
  end
  local lib = require('wincent.commandt.private.lib')
  finder.scanner = require('wincent.commandt.private.scanners.find').scanner(directory)
  finder.matcher = lib.matcher_new(finder.scanner, options)
  finder.run = function(query)
    local results = lib.matcher_run(finder.matcher, query)
    local strings = {}
    for i = 0, results.count - 1 do
      local str = results.matches[i]
      table.insert(strings, ffi.string(str.contents, str.length))
    end
    return strings
  end
  finder.open = function(item, kind)
    options.open(vim.fn.fnameescape(item), kind)
  end
  return finder
end
