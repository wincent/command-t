-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local is_list = require('wincent.commandt.private.is_list')

local M = {}

function M.setup()
  if _G.vim == nil then
    _G.vim = {}
  end

  -- Implemented - enough to support:
  --
  -- vim.iter(list_of_lists):flatten():totable()

  local Iter = {}
  Iter.__index = Iter

  function Iter.new(list)
    if not is_list(list) then
      error('non-list table passed to Iter.new() stub')
    end
    local self = setmetatable({}, Iter)
    self._list = list
    return self
  end

  function Iter:flatten()
    local flattened = {}
    for _, item in ipairs(self._list) do
      if is_list(item) then
        for _, nested in ipairs(item) do
          table.insert(flattened, nested)
        end
      else
        table.insert(flattened, item)
      end
    end
    self._list = flattened
    return self
  end

  function Iter:totable()
    return self._list
  end

  vim.iter = function(list)
    return Iter.new(list)
  end
end

return M
