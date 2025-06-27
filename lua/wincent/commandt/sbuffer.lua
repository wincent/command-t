-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- "Smart" open that will switch to an already open window containing the
--- specified `buffer`, if one exists; otherwise, it will open a new window
--- using `command` (which should be one of `edit`, `tabedit`, `split`, or
--- `vsplit`).
---
--- @param buffer string
--- @param command 'edit' | 'split' | 'tabedit' | 'vsplit'
--- @return nil
local function sbuffer(buffer, command)
  local escaped_name = vim.fn.fnameescape(buffer)
  local is_visible = require('wincent.commandt.private.buffer_visible')(escaped_name)
  if is_visible then
    -- Note that, in order to be useful, `:sbuffer` needs `vim.o.switchbuf =
    -- 'usetab'` to be set.
    vim.cmd('sbuffer ' .. escaped_name)
  else
    vim.cmd(command .. ' ' .. escaped_name)
  end
end

return sbuffer
