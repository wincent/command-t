-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local c = require('wincent.commandt.private.lib.c')

local function watchman_disconnect(socket)
  -- TODO: validate socket is a number
  local errno = c.commandt_watchman_disconnect(socket)
  if errno ~= 0 then
    error('commandt_watchman_disconnect(): failed with errno ' .. errno)
  end
end

return watchman_disconnect
