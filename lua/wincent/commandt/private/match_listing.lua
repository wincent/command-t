-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local match_listing = {}

local Window = require('wincent.commandt.private.window').Window

local window = nil

local border_height = 2
local prompt_height = 1 + border_height

match_listing.show = function(options)
  -- TODO: deal with options
  -- eg matchlistingattop etc
  if window == nil then
    window = Window.new({
      bottom = prompt_height,
      filetype = 'CommandTMatchListing',
      height = 15, -- TODO: configurable
      onclose = function()
        window = nil
      end,
      title = 'Results',
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
