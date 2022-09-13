-- SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local list = {}

-- Basic scanner that returns the supplied list of candidates.
list.scanner = function(candidates)
  local lib = require('wincent.commandt.private.lib')
  local scanner = lib.scanner_new_copy(candidates)
  return scanner
end

return list
