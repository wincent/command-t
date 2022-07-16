-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local prompt = {}

local Window = require('wincent.commandt.private.window').Window

local window = nil

prompt.show = function(options)
  -- TODO: merge options
  if window == nil then
    window = Window.new({
      buftype = 'prompt',
      filetype = 'CommandTPrompt',
      onchange = function(contents)
        if options and options.onchange then
          options.onchange(contents)
        end
      end,
      title = 'CommandT [type]', -- TODO make real
    })
  end
  window:show()
  window:focus()
end

return prompt
