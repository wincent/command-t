-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local help = {}

local helptags = nil

-- Returns the list of helptags that can be opened with `:help {tag}`
--
-- Will return a cached value unless `force` is truthy (or there is no cached
-- value).
local get = function(force)
  if helptags == nil or force then
    -- Neovim doesn't provide an easy way to get a list of all help tags.
    -- `tagfiles()` only shows the tagfiles for the current buffer, so you need
    -- to already be in a buffer of `'buftype'` `help` for that to work.
    -- Likewise, `taglist()` only shows tags that apply to the current file
    -- type, and `:tag` has the same restriction.
    --
    -- So, we look for "doc/tags" files at every location in the `'runtimepath'`
    -- and try to manually parse it.
    helptags = {}

    local tagfiles = vim.api.nvim_get_runtime_file('doc/tags', true)

    for _, tagfile in ipairs(tagfiles) do
      if vim.fn.filereadable(tagfile) then
        for _, tag in ipairs(vim.fn.readfile(tagfile)) do
          local _, _, tag_text = tag:find('^%s*(%S+)%s+')
          if tag_text ~= nil then
            table.insert(helptags, tag_text)
          end
        end
      end
    end
  end

  return helptags
end

help.scanner = function()
  local paths = get()
  local lib = require('wincent.commandt.private.lib')
  local scanner = lib.scanner_new_copy(paths)
  return scanner
end

return help
