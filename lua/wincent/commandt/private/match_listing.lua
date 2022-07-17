-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local match_listing = {}

local Window = require('wincent.commandt.private.window').Window
local merge = require('wincent.commandt.private.merge')

local window = nil

local border_height = 2
local prompt_height = 1 + border_height

match_listing.show = function(options)
  options = merge({
    height = 15,
    order = 'reverse',
    position = 'bottom',
  }, options or {})

  local bottom = nil
  local top = nil
  if options.position == 'bottom' then
    bottom = prompt_height
  else
    top = prompt_height
  end

  -- TODO: deal with other options, like reverse
  if window == nil then
    window = Window.new({
      bottom = bottom,
      filetype = 'CommandTMatchListing',
      height = options.height,
      onclose = function()
        window = nil
      end,
      title = '',
      top = top,
    })
  end
  window:show()
end

match_listing.update = function(results)
  if window then
    window:replace_lines(results)
  end
end

return match_listing
