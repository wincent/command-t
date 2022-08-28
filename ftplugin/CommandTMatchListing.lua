-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

vim.bo.bufhidden = 'wipe'
vim.bo.textwidth = 0
vim.wo.concealcursor = ''
vim.wo.conceallevel = 0
vim.wo.winhighlight = 'IncSearch:Normal,Search:Normal'

-- Would like this to be false, but that produces rendering glitches in
-- conjunction with vim-dirvish, so instead we turn wrapping on but trim our
-- match listing text so that it is never wide enough to actually cause
-- wrapping.
vim.wo.wrap = true
