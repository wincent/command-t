-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local includes = require('wincent.commandt.private.includes')

local Settings = {}

local settings = { 'hlsearch' }

local mt = {
  __index = Settings,
  __newindex = function(t, key, value)
    local saved = rawget(t, '_saved')
    if includes(settings, key) then
      if value == nil then
        if saved[key] ~= nil then
          -- Reset to previously saved value.
          vim.opt[key] = saved[key]
          saved[key] = nil
        end
      else
        if saved[key] == nil then
          -- Save current value.
          saved[key] = vim.o[key]
        end
        vim.opt[key] = value
      end
    else
      rawset(t, key, value)
    end
  end,
}

function Settings.new()
  local m = {
    _saved = {},
  }
  setmetatable(m, mt)
  return m
end

return Settings
