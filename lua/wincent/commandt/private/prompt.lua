-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local prompt = {}

local Window = require('wincent.commandt.private.window').Window
local merge = require('wincent.commandt.private.merge')

local Prompt = {}

local mt = {
  __index = Prompt,
}

function Prompt.new(options)
  options = merge({
    margin = 0,
    on_change = nil,
    on_next = nil,
    on_previous = nil,
    on_select = nil,
    position = 'bottom',
  }, options or {})
  -- TODO validate options
  local p = {
    _margin = options.margin,
    _on_change = options.on_change,
    _on_next = options.on_next,
    _on_select = options.on_select,
    _on_previous = options.on_previous,
    _position = options.position,
    _window = nil,
  }
  setmetatable(p, mt)
  return p
end

function Prompt:close()
  if self._window then
    self._window:close()
  end
end

function Prompt:show()
  local bottom = nil
  local top = nil
  if self._position == 'center' then
    local available_height = vim.o.lines - vim.o.cmdheight
    local used_height = 15 -- note we need to know how high the match listing is going to be
      + 2 -- match listing border
      + 3 -- our height
    local remaining_height = available_height - used_height -- TODO deal with overflow
    top = math.floor(remaining_height / 2)
  elseif self._position == 'bottom' then
    bottom = 0
  else
    top = 0
  end

  if self._window == nil then
    self._window = Window.new({
      bottom = bottom,
      buftype = 'prompt',
      filetype = 'CommandTPrompt',
      margin = self._margin,
      on_change = function(contents)
        if self._on_change then
          self._on_change(contents)
        end
      end,
      on_close = function()
        print('got on_close for prompt')
        self._window = nil
      end,
      on_leave = function()
        print('got on_leave for prompt')
        if self._window then
          self._window:close()
        end
      end,
      title = 'CommandT [type]', -- TODO make real
      top = top,
    })
  end

  self._window:show()
  -- Probably don't want INSERT mode mapping (ie. so user can navigate prompt in
  -- normal mode).
  self._window:nmap('<Esc>', function()
    if self._window then
      self._window:close()
    end
  end)
  self._window:map({ 'i', 'n' }, { '<Down>', '<C-j>' }, function()
    if self._on_next then
      self._on_next()
    end
  end)
  self._window:map({ 'i', 'n' }, { '<Up>', '<C-k>' }, function()
    if self._on_previous then
      self._on_previous()
    end
  end)
  self._window:map({ 'i', 'n' }, { '<CR>' }, function()
    if self._on_select then
      self._on_select()
    end
  end)
  self._window:focus()
end

prompt.Prompt = Prompt

return prompt
