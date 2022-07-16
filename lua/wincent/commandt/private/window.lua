-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Convenience wrapper around Neovim floating windows.
--
-- Manages a floating window and associated buffer, and provides methods for
-- positioning, updating, setting a title etc.

local window = {}

local Window = {}

local mt = {
  __index = Window,
}

function Window.new(options)
  options = merge({
    height = 1,
    position = 'bottom',
    buftype = 'nofile', -- Also, 'prompt'.
    filetype = nil,
    --onclose = nil,
    onchange = nil,
  }, options)
  local w = {
    _buftype = options.buftype,
    _filetype = options.filetype,
    _height = options.height,
    _main_buffer = nil,
    _main_window = nil,
    _onchange = options.onchange,
    _position = options.position,
    _title_buffer = nil,
    _title_window = nil,
  }
  setmetatable(w, mt)
  return w
end

-- Focus the window and enter insert mode, ready to receive input.
function Window:focus()
  -- TODO: if not shown, show first, then...
  vim.api.nvim_set_current_win(self.main_window)
  vim.cmd('startinsert')
end

function Window:show()
  if self.main_buffer == nil then
  end
  if self.main_window == nil then
  end
  if self.title_buffer == nil then
  end
  if self.title_window == nil then
  end
  -- TODO: position title
end

window.Window = Window

return window
