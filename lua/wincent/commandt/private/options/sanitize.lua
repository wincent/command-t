-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

--- Returns a sanitized copy of `options` (with bad values fixed, if possible),
--- and a table of errors. `base`, if provided, is an options object to extend.
local function sanitize(options, base)
  local copy = require('wincent.commandt.private.copy')
  local defaults = require('wincent.commandt.private.options.defaults')
  local is_table = require('wincent.commandt.private.is_table')
  local merge = require('wincent.commandt.private.merge')
  local schema = require('wincent.commandt.private.options.schema')
  local validate = require('wincent.commandt.private.validate')

  local errors = {}

  options = copy(options or {})
  if not is_table(options) then
    table.insert(errors, 'expected a table of options but received ' .. type(options))
    options = {}
  end
  if base ~= nil then
    options = merge(base, options)
  end

  errors = merge(errors, validate('', nil, options, schema, defaults:clone(options)))
  return options, errors
end

return sanitize
