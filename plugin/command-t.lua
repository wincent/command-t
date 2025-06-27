-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

vim.keymap.set('n', '<Plug>(CommandT)', ':CommandT<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTBuffer)', ':CommandTBuffer<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTCommand)', ':CommandTCommand<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTFd)', ':CommandTFd<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTFind)', ':CommandTFind<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTGit)', ':CommandTGit<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTHistory)', ':CommandTHistory<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTHelp)', ':CommandTHelp<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTJump)', ':CommandTJump<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTLine)', ':CommandTLine<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTRipgrep)', ':CommandTRipgrep<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTSearch)', ':CommandTSearch<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTTag)', ':CommandTTag<CR>', { silent = true })
vim.keymap.set('n', '<Plug>(CommandTWatchman)', ':CommandTWatchman<CR>', { silent = true })

vim.api.nvim_create_user_command('CommandT', function(command)
  require('wincent.commandt.finder')('file', command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command('CommandTBuffer', function()
  require('wincent.commandt.finder')('buffer')
end, {
  nargs = 0,
})

vim.api.nvim_create_user_command('CommandTCommand', function()
  require('wincent.commandt.finder')('command')
end, {
  nargs = 0,
})

vim.api.nvim_create_user_command('CommandTFd', function(command)
  require('wincent.commandt.finder')('fd', command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command('CommandTFind', function(command)
  require('wincent.commandt.finder')('find', command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command('CommandTGit', function(command)
  require('wincent.commandt.finder')('git', command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command('CommandTHelp', function()
  require('wincent.commandt.finder')('help')
end, {
  nargs = 0,
})

vim.api.nvim_create_user_command('CommandTHistory', function()
  require('wincent.commandt.finder')('history')
end, {
  nargs = 0,
})

vim.api.nvim_create_user_command('CommandTJump', function()
  require('wincent.commandt.finder')('jump')
end, {
  nargs = 0,
})

vim.api.nvim_create_user_command('CommandTLine', function()
  require('wincent.commandt.finder')('line')
end, {
  nargs = 0,
})

vim.api.nvim_create_user_command('CommandTRipgrep', function(command)
  require('wincent.commandt.finder')('rg', command.args)
end, {
  complete = 'dir',
  nargs = '?',
})

vim.api.nvim_create_user_command('CommandTSearch', function()
  require('wincent.commandt.finder')('search')
end, {
  nargs = 0,
})

vim.api.nvim_create_user_command('CommandTTag', function()
  require('wincent.commandt.finder')('tag')
end, {
  nargs = 0,
})

vim.api.nvim_create_user_command('CommandTWatchman', function(command)
  require('wincent.commandt.finder')('watchman', command.args)
end, {
  complete = 'dir',
  nargs = '?',
})
