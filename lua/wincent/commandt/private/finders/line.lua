-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local force_dot_files = require('wincent.commandt.private.options.force_dot_files')

local line = {
  candidates = function(_directory, _options)
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local result = {}
    for i, line in ipairs(lines) do
      -- Skip blank/empty lines.
      if not line:match('^%s*$') then
        table.insert(result, vim.trim(line) .. ':' .. tostring(i))
      end
    end
    return result
  end,
  mode = 'virtual',
  open = function(item, _ex_command, _directory, _options, _context)
    -- Extract line number from (eg) "some line contents:100".
    local suffix = string.find(item, '%d+$')
    local index = tonumber(item:sub(suffix))
    vim.api.nvim_win_set_cursor(0, { index, 0 })
  end,
  options = force_dot_files,
}

return line
