-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_integer = require('wincent.commandt.private.is_integer')

---@alias BorderOption
---| 'double'
---| 'none'
---| 'rounded'
---| 'shadow'
---| 'single'
---| 'solid'
---| 'winborder'
---| string[]
local border = {
  kind = {
    one_of = {
      'double',
      'none',
      'rounded',
      'shadow',
      'single',
      'solid',
      'winborder',
      { kind = 'list', of = { kind = 'string' } },
    },
  },
}

---@alias MappingsOption {
---    i?: table<string, string>,
---    n?: table<string, string>
---}
local mappings = {
  kind = 'table',
  keys = {
    i = {
      kind = 'table',
      values = { kind = 'string' },
    },
    n = {
      kind = 'table',
      values = { kind = 'string' },
    },
  },
}

---@alias ModeOption 'file' | 'virtual'
local mode = { kind = { one_of = { 'file', 'virtual' } }, optional = true }

---@alias OrderOption 'forward' | 'reverse'
local order = { kind = { one_of = { 'forward', 'reverse' } } }

---@alias PositionOption 'bottom' | 'center' | 'top'
local position = { kind = { one_of = { 'bottom', 'center', 'top' } } }

---@alias TraverseOption 'file' | 'pwd' | 'none'
local traverse = { kind = { one_of = { 'file', 'pwd', 'none' } } }

---@alias TruncateOption
---| 'beginning'
---| 'middle'
---| 'end'
---| 'true'
---| 'false'
---| boolean
local truncate = {
  kind = {
    one_of = {
      'beginning',
      'middle',
      'end',
      'true',
      'false',
      { kind = 'boolean' },
    },
  },
}

return {
  border = border,
  height = {
    kind = 'number',
    meta = function(context)
      if not is_integer(context.height) or context.height < 1 then
        context.height = 15
        return '`height` must be a positive integer'
      end
    end,
  },
  mappings = mappings,
  margin = {
    kind = 'number',
    meta = function(context)
      if not is_integer(context.margin) or context.margin < 0 then
        context.margin = 0
        return '`margin` must be a non-negative integer'
      end
    end,
  },
  mode = mode,
  order = order,
  position = position,
  traverse = traverse,
  truncate = truncate,
}
