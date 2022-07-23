-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local CommandT = nil
local CommandTBuffer = nil
local CommandTHelp = nil
local CommandTWatchman = nil

if vim.g.CommandTPreferredImplementation == 'lua' then
  CommandT = 'CommandT'
  CommandTBuffer = 'CommandTBuffer'
  CommandTHelp = 'CommandTHelp'
  CommandTWatchman = 'CommandTWatchman'

  vim.keymap.set('n', '<Plug>(CommandT)', ':CommandT<CR>', { silent = true })
  vim.keymap.set('n', '<Plug>(CommandTBuffer)', ':CommandTBuffer<CR>', { silent = true })
  vim.keymap.set('n', '<Plug>(CommandTHelp)', ':CommandTHelp<CR>', { silent = true })
else
  CommandT = 'KommandT'
  CommandTBuffer = 'KommandTBuffer'
  CommandTHelp = 'KommandTHelp'
  CommandTWatchman = 'KommandTWatchman'
end

vim.api.nvim_create_user_command(CommandT, function(command)
  require('wincent.commandt').file_finder(command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command(CommandTBuffer, function()
  require('wincent.commandt').buffer_finder()
end, {})

vim.api.nvim_create_user_command(CommandTHelp, function()
  require('wincent.commandt').help_finder()
end, {})

vim.api.nvim_create_user_command(CommandTWatchman, function(command)
  require('wincent.commandt').watchman_finder(command.args)
end, {
  complete = 'dir',
  nargs = '?',
})
