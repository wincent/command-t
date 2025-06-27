-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local force_dot_files = require('wincent.commandt.private.options.force_dot_files')

-- Module-level global state.
local help_opened = false

local help = {
  candidates = function(_directory, _options)
    -- Neovim doesn't provide an easy way to get a list of all help tags.
    -- `tagfiles()` only shows the tagfiles for the current buffer, so you need
    -- to already be in a buffer of `'buftype'` `help` for that to work.
    -- Likewise, `taglist()` only shows tags that apply to the current file
    -- type, and `:tag` has the same restriction.
    --
    -- So, we look for "doc/tags" files at every location in the `'runtimepath'`
    -- and try to manually parse it.
    local helptags = {}
    local tagfiles = vim.api.nvim_get_runtime_file('doc/tags', true)
    for _, tagfile in ipairs(tagfiles) do
      if vim.fn.filereadable(tagfile) == 1 then
        for _, tag in ipairs(vim.fn.readfile(tagfile)) do
          local _, _, tag_text = tag:find('^%s*(%S+)%s+')
          if tag_text ~= nil then
            table.insert(helptags, tag_text)
          end
        end
      end
    end
    return helptags
  end,
  mode = 'virtual',
  open = function(item, ex_command, _directory, _options, _context)
    local command = 'help'
    if ex_command == 'split' then
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
    elseif ex_command == 'tabedit' then
      command = 'tab help'
    elseif ex_command == 'vsplit' then
      command = 'vertical help'
    end

    -- E434 "Can't find tag pattern" is innocuous, so swallow it. For more
    -- context, see: https://github.com/autozimu/LanguageClient-neovim/pull/731
    vim.cmd('try | ' .. command .. ' ' .. item .. ' | catch /E434/ | endtry')
  end,
  options = force_dot_files,
}

return help
