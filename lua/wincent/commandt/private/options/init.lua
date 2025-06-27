-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local Options = {}

local mt = {
  __index = Options,
}

function Options.new()
  local instance = {
    _storage = nil,
  }
  setmetatable(instance, mt)
  return instance
end

--- Returns a copy of stored (configured) options, if any.
function Options:get()
  local copy = require('wincent.commandt.private.copy')
  return copy(self._storage)
end

--- Sets the stored (configured) options to `value`.
function Options:set(value)
  self._storage = value
end

-- Singleton instance.
local options = Options.new()

return options
