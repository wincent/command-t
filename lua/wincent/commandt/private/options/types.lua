-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_integer = require('wincent.commandt.private.is_integer')

return {
  border = {
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
  },
  height = {
    kind = 'number',
    meta = function(context)
      if not is_integer(context.height) or context.height < 1 then
        context.height = 15
        return '`height` must be a positive integer'
      end
    end,
  },
  mappings = {
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
  },
  margin = {
    kind = 'number',
    meta = function(context)
      if not is_integer(context.margin) or context.margin < 0 then
        context.margin = 0
        return '`margin` must be a non-negative integer'
      end
    end,
  },
  position = { kind = { one_of = { 'bottom', 'center', 'top' } } },
  truncate = {
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
  },
}
