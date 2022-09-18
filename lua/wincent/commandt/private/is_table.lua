-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_list = require('wincent.commandt.private.is_list')

local is_table = function(value)
  return type(value) == 'table' and (#value == 0 or not is_list(value))
end

return is_table
