-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local prompt = {}

local Window = require('wincent.commandt.private.window').Window
local merge = require('wincent.commandt.private.merge')

local window = nil

prompt.show = function(options)
  options = merge({
    position = 'bottom',
  }, options or {})

  local bottom = nil
  local top = nil
  if options.position == 'bottom' then
    bottom = 0
  else
    top = 0
  end

  if window == nil then
    window = Window.new({
      bottom = bottom,
      buftype = 'prompt',
      filetype = 'CommandTPrompt',
      onchange = function(contents)
        if options and options.onchange then
          options.onchange(contents)
        end
      end,
      onclose = function()
        window = nil
      end,
      title = 'CommandT [type]', -- TODO make real
      top = top,
    })
  end
  window:show()
  window:focus()
end

return prompt
