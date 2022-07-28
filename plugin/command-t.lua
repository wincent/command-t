-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local CommandT = nil
local CommandTBuffer = nil
local CommandTHelp = nil
local CommandTWatchman = nil

if vim.g.CommandTPreferredImplementation == 'lua' then
  CommandT = 'CommandT'
  CommandTBuffer = 'CommandTBuffer'
  CommandTFind = 'CommandTFind'
  CommandTGit = 'CommandTGit'
  CommandTHelp = 'CommandTHelp'
  CommandTRipgrep = 'CommandTRipgrep'
  CommandTWatchman = 'CommandTWatchman'

  vim.keymap.set('n', '<Plug>(CommandT)', ':CommandT<CR>', { silent = true })
  vim.keymap.set('n', '<Plug>(CommandTBuffer)', ':CommandTBuffer<CR>', { silent = true })
  vim.keymap.set('n', '<Plug>(CommandTFind)', ':CommandTFind<CR>', { silent = true })
  vim.keymap.set('n', '<Plug>(CommandTGit)', ':CommandTGit<CR>', { silent = true })
  vim.keymap.set('n', '<Plug>(CommandTHelp)', ':CommandTHelp<CR>', { silent = true })
  vim.keymap.set('n', '<Plug>(CommandTRipgrep)', ':CommandTRipgrep<CR>', { silent = true })
  vim.keymap.set('n', '<Plug>(CommandTWatchman)', ':CommandTWatchman<CR>', { silent = true })
else
  CommandT = 'KommandT'
  CommandTBuffer = 'KommandTBuffer'
  CommandTFind = 'KommandTFind'
  CommandTGit = 'KommandTGit'
  CommandTHelp = 'KommandTHelp'
  CommandTRipgrep = 'CommandTRipgrep'
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

vim.api.nvim_create_user_command(CommandTFind, function(command)
  require('wincent.commandt').find_finder(command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command(CommandTGit, function(command)
  require('wincent.commandt').git_finder(command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command(CommandTHelp, function()
  require('wincent.commandt').help_finder()
end, {})

vim.api.nvim_create_user_command(CommandTRipgrep, function(command)
  require('wincent.commandt').rg_finder(command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command(CommandTWatchman, function(command)
  require('wincent.commandt').watchman_finder(command.args)
end, {
  complete = 'dir',
  nargs = '?',
})
