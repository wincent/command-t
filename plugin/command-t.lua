-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

vim.cmd([[
  command! KommandTBuffer lua require'wincent.commandt'.buffer_finder()
  command! -nargs=? -complete=dir KommandT call luaeval("require'wincent.commandt'.file_finder(_A)", <q-args>)

  augroup WincentCommandT
    autocmd!
  augroup END
]])
