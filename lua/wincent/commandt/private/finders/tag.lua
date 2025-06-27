-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local force_dot_files = require('wincent.commandt.private.options.force_dot_files')
local keys = require('wincent.commandt.private.keys')
local sbuffer = require('wincent.commandt.sbuffer')

local tag = {
  candidates = function(_directory, options)
    local include_filenames = options.scanners.tag.include_filenames
    local tags = vim.fn.taglist('.')
    local candidates = {}

    for _, tag in ipairs(tags) do
      local item = tag.name
      if include_filenames and tag.filename then
        item = item .. ':' .. tag.filename
      end
      candidates[item] = tag
    end

    local result = keys(candidates)
    table.sort(result)

    -- In addition to returning `result`, return `candidates` as context.
    return result, candidates
  end,
  mode = 'virtual',
  open = function(item, ex_command, _directory, options, context)
    local tag = context[item]
    sbuffer(tag.filename, ex_command)

    -- Strip leading and trailing slashes, and use \M ('nomagic'):
    -- ie. "/^int main()$/" → "\M^int main()$"
    local pattern = '\\M' .. tag.cmd:match('^/(.-)/?$')
    local line, column = unpack(vim.fn.searchpos(pattern, 'w'))
    if line ~= 0 and column ~= 0 then
      vim.cmd('normal! zz')
    end
  end,
  options = force_dot_files,
}

return tag
