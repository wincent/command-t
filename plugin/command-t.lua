-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

vim.api.nvim_create_user_command('KommandT', function(command)
  require('wincent.commandt').file_finder(command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command('KommandTBuffer', function()
  require('wincent.commandt').buffer_finder()
end, {})

vim.api.nvim_create_user_command('KommandTHelp', function()
  require('wincent.commandt').help_finder()
end, {})

vim.api.nvim_create_user_command('KommandTWatchman', function(command)
  require('wincent.commandt').watchman_finder(command.args)
end, {
  complete = 'dir',
  nargs = '?',
})
