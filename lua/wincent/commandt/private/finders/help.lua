-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local help_opened = false

return function(options)
  local lib = require('wincent.commandt.private.lib')
  local finder = {}
  finder.scanner = require('wincent.commandt.private.scanners.help').scanner()
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
    local command = 'help'
    if kind == 'split' then
      -- Split is the default, so for this finder, we abuse "split" mode to do
      -- the opposite of the default, using tricks noted in `:help help-curwin`.
      --
      -- See also: https://github.com/vim/vim/issues/7534
      if not help_opened then
        vim.cmd([[
          silent noautocmd keepalt help
          silent noautocmd keepalt helpclose
        ]])
        help_opened = true
      end
      if vim.fn.empty(vim.fn.getcompletion(item, 'help')) == 0 then
        vim.cmd('silent noautocmd keepalt edit ' .. vim.o.helpfile)
      end
    elseif kind == 'tabedit' then
      command = 'tab help'
    elseif kind == 'vsplit' then
      command = 'vertical help'
    end

    -- E434 "Can't find tag pattern" is innocuous, so swallow it. For more
    -- context, see: https://github.com/autozimu/LanguageClient-neovim/pull/731
    vim.cmd('try | ' .. command .. ' ' .. item .. ' | catch /E434/ | endtry')
  end
  return finder
end
