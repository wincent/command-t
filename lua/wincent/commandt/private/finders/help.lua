-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

return function(options)
  local lib = require('wincent.commandt.private.lib')
  local finder = {}
  -- TODO: make `dir` actually do something here
  finder.scanner = require('wincent.commandt.private.scanners.help').scanner()
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
  finder.select = function(item, kind)
    -- E434 "Can't find tag pattern" is innocuous, so swallow it. For more
    -- context, see: https://github.com/autozimu/LanguageClient-neovim/pull/731
    vim.cmd('try | help ' .. item .. ' | catch /E434/ | endtry')
    -- TODO: see if I can do anything useful here...
    --options.select(vim.fn.fnameescape(item), kind)
  end
  return finder
end
