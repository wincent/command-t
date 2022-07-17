-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local prompt = {}

local Window = require('wincent.commandt.private.window').Window
local merge = require('wincent.commandt.private.merge')

local window = nil

prompt.show = function(options)
  options = merge({
    margin = 0,
    position = 'bottom',
  }, options or {})
  -- TODO: allow left/right margins to be set as well

  local bottom = nil
  local top = nil
  if options.position == 'center' then
    local available_height = vim.o.lines - vim.o.cmdheight
    local used_height = 15 -- note we need to know how high the match listing is going to be
      + 2 -- match listing border
      + 3 -- our height
    local remaining_height = available_height - used_height -- TODO deal with overflow
    top = math.floor(remaining_height / 2)
  elseif options.position == 'bottom' then
    bottom = 0
  else
    top = 0
  end

  if window == nil then
    window = Window.new({
      bottom = bottom,
      buftype = 'prompt',
      filetype = 'CommandTPrompt',
      margin = options.margin,
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
