-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

return function(directory, options, name)
  local lib = require('wincent.commandt.private.lib')
  local command = options.finders[name].command
  command = type(command) == 'string' and command or command(directory)
  local finder = {}
  finder.scanner = require('wincent.commandt.private.scanners.command').scanner(command)
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
  finder.open = options.finders[name].open
    or function(item, kind)
      options.open(vim.fn.fnameescape(item), kind)
    end
  return finder
end
