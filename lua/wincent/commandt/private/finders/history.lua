-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local force_dot_files = require('wincent.commandt.private.options.force_dot_files')

local history = {
  candidates = function(_directory, _options)
    local result = vim.api.nvim_exec2('history :', { output = true })
    local commands = {}
    for line in result.output:gmatch('[^\r\n]+') do
      local command = line:gsub('^%s*%d+%s+', '')
      table.insert(commands, command)
    end
    return commands
  end,
  mode = 'virtual',
  open = function(item, _ex_command, _directory, _options, _context)
    vim.api.nvim_feedkeys(':' .. item, 'nt', true)
  end,
  options = force_dot_files,
}

return history
