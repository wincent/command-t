-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

vim.cmd([[
  command! -nargs=? KommandTDemo call luaeval("require'wincent.commandt'.demo(_A)", <q-args>)
  command! KommandTBuffer lua require'wincent.commandt'.buffer_finder()
  command! -nargs=? -complete=dir KommandT call luaeval("require'wincent.commandt'.file_finder(_A)", <q-args>)

  command! KommandTPrompt lua require'wincent.commandt'.prompt()

  augroup WincentCommandT
    autocmd!

    autocmd CmdlineChanged * call luaeval("require'wincent.commandt'.cmdline_changed(_A)", expand('<afile>'))
    autocmd CmdlineEnter * lua require'wincent.commandt'.cmdline_enter()
    autocmd CmdlineLeave * lua require'wincent.commandt'.cmdline_leave()
  augroup END
]])
