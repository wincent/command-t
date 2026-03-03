-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local c = require('wincent.commandt.private.lib.c')

local function watchman_connect(name)
  -- TODO: validate name is a string/path
  local socket = c.commandt_watchman_connect(name)
  if socket == -1 then
    error('commandt_watchman_connect(): failed')
  end
  return socket
end

return watchman_connect
