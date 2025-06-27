-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Common `on_open` implementation used by several "command" finders that equips
-- them to deal with automatic directory changes caused by the `traverse`
-- setting.
local function on_open(item, ex_command, directory, _options, _context)
  local sbuffer = require('wincent.commandt.sbuffer')
  local relativize = require('wincent.commandt.private.relativize')
  sbuffer(relativize(directory, item), ex_command)
end

-- TODO: maybe rename this (file and function)
return on_open
