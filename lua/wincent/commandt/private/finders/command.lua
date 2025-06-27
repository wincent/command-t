-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local force_dot_files = require('wincent.commandt.private.options.force_dot_files')
local keys = require('wincent.commandt.private.keys')

local command = {
  candidates = function(_directory, _options)
    -- Maybe Neovim will support builtins here too one day, but it doesn't
    -- yet.
    local commands = keys(vim.api.nvim_get_commands({ builtin = false }))

    -- For now, read builtins from `:help ex-cmd-index`.
    local ex_cmd_index = vim.fn.expand(vim.fn.findfile('doc/index.txt', vim.o.runtimepath))
    if vim.fn.filereadable(ex_cmd_index) == 1 then
      -- Parse table in file, which should have the form:
      --
      --     tag          command     action ~
      --     ------------------------------------------------------------ ~
      --     |:|          :           nothing
      --     |:range|     :{range}    go to last line in {range}
      --
      --     (continues for 100s of lines...)
      --
      for _, line in ipairs(vim.fn.readfile(ex_cmd_index)) do
        local command = line:match('^|:([^|]+)|%s+')
        if command then
          table.insert(commands, command)
        end
      end
    end
    return commands
  end,
  mode = 'virtual',
  open = function(item, _ex_command, _directory, _options, _context)
    vim.api.nvim_feedkeys(':' .. item, 'nt', true)
  end,
  options = force_dot_files,
}

return command
