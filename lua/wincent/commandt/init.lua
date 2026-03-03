-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local commandt = {}

commandt.setup = function(new_options)
  local options = require('wincent.commandt.private.options')
  local defaults = require('wincent.commandt.private.options.defaults')
  local sanitize = require('wincent.commandt.private.options.sanitize')
  local sanitized_options, errors = sanitize(new_options, options:get() or defaults:clone(new_options))
  options:set(sanitized_options)
  if
    not pcall(function()
      -- Test that we can require and use something implemented in C.
      local epoch = require('wincent.commandt.private.lib.epoch')
      epoch()
    end)
  then
    table.insert(errors, 'unable to load and use C library - run `:checkhealth wincent.commandt`')
  end

  local report_errors = require('wincent.commandt.private.report_errors')
  report_errors(errors, 'commandt.setup()')
end

return commandt
