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
  if options.position == 'center' then
    local available_height = vim.o.lines - vim.o.cmdheight
    local used_height = 15 -- note we need to know how high the match listing is going to be
      + 2 -- match listing border
      + 3 -- our height
    local remaining_height = available_height - used_height -- TODO deal with overflow
    top = math.floor(remaining_height / 2) + 3 -- prompt height
  elseif options.position == 'bottom' then
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
    window:replace_lines(results, { adjust_height = true })
  end
end

return match_listing
