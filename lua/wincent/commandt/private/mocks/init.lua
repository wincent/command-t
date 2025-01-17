-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local mocks = setmetatable({}, {
  __index = function(t, key)
    if key == 'vim' then
      local mock = require('wincent.commandt.private.mocks.vim')
      t[key] = mock
      return mock
    end
  end,
})

return mocks
