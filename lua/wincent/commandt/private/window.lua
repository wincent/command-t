-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Convenience wrapper around Neovim floating windows.
--
-- Manages a floating window and associated buffer, and provides methods for
-- positioning, updating, setting a title etc.

local window = {}

local merge = require('wincent.commandt.private.merge')

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
    prompt = '> ',
    title = 'Command-T',
  }, options)
  local w = {
    _buftype = options.buftype,
    _filetype = options.filetype,
    _height = options.height,
    _main_buffer = nil,
    _main_window = nil,
    _onchange = options.onchange,
    _position = options.position,
    _prompt = options.prompt,
    _title = options.title,
    _title_buffer = nil,
    _title_window = nil,
  }
  setmetatable(w, mt)
  return w
end

-- Focus the window and enter insert mode, ready to receive input.
function Window:focus()
  -- TODO: if not shown, show first automatically?, then...
  vim.api.nvim_set_current_win(self._main_window)
  vim.cmd('startinsert')
end

function Window:show()
  if self._main_buffer == nil then
    self._main_buffer = vim.api.nvim_create_buf(
      false, -- listed = false
      true -- scratch = true
    )
    if self._main_buffer == 0 then
      error('Window:show(): nvim_create_buf() failed')
    end
    local ps1 = self._prompt or '> '
    if self._buftype == 'prompt' then
      vim.api.nvim_buf_set_option(self._main_buffer, 'buftype', 'prompt')
      vim.fn.prompt_setprompt(self._main_buffer, ps1)
    end
    if self._filetype ~= nil then
      vim.api.nvim_buf_set_option(self._main_buffer, 'filetype', self._filetype)
    end
    if self._onchange then
      local callback = function()
        -- Should be able to use `vim.fn.prompt_getprompt(self._main_buffer)`,
        -- but it only returns the prompt prefix for some reason...
        local query = vim.api.nvim_get_current_line():sub(#ps1 + 1)
        self._onchange(query)
      end
      vim.api.nvim_create_autocmd('TextChanged', {
        buffer = self._main_buffer,
        callback = callback,
      })
      vim.api.nvim_create_autocmd('TextChangedI', {
        buffer = self._main_buffer,
        callback = callback,
      })
    end
  end
  if self._main_window == nil then
    local width = vim.o.columns
    self._main_window = vim.api.nvim_open_win(
      self._main_buffer,
      true, -- enter = true
      {
        border = 'single',
        col = 0,
        focusable = false,
        height = 1,
        noautocmd = true,
        relative = 'editor',
        row = vim.o.lines - 3,
        style = 'minimal',
        width = width,
      }
    )
    if self._main_window == 0 then
      error('Window:show(): nvim_open_win() failed')
    end
    -- TODO: maybe watch for buffer destruction too
    -- TODO: watch for resize events
    vim.api.nvim_create_autocmd('WinClosed', {
      once = true,
      callback = function()
        self._main_window = nil
      end,
    })
    vim.api.nvim_win_set_option(self._main_window, 'wrap', false)
    -- TODO: decide whether I need to clear lines here.
    vim.api.nvim_buf_set_lines(
      self._main_buffer,
      0, -- start
      -1, -- end
      false, -- strict indexing = false
      {} -- replacement lines
    )
  end
  if self._title_buffer == nil then
    self._title_buffer = vim.api.nvim_create_buf(
      false, -- listed = false
      true -- scratch = true
    )
    if self._title_buffer == 0 then
      error('Window:show(): nvim_create_buf() failed')
    end
    vim.api.nvim_buf_set_option(self._title_buffer, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(self._title_buffer, 'filetype', 'CommandTTitle')
  end
  local prompt_title = ' ' .. self._title .. ' '
  if self._title_window == nil then
    self._title_window = vim.api.nvim_open_win(
      self._title_buffer,
      false, -- enter = false
      {
        col = 3,
        focusable = false,
        height = 1,
        noautocmd = true,
        relative = 'editor',
        row = vim.o.lines - 4,
        style = 'minimal',
        width = #prompt_title,
        zindex = 60, -- Default for floats is 50
      }
    )
    if self._title_window == 0 then
      error('Window:show(): nvim_open_win() failed')
    end
  end
  -- TODO: position title autoatically
  vim.api.nvim_buf_set_lines(
    self._title_buffer,
    0, -- start
    -1, -- end
    false, -- strict indexing
    { prompt_title } -- TODO: put actual type
  )
end

window.Window = Window

return window
