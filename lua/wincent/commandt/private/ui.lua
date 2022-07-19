-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ui = {}

local MatchListing = require('wincent.commandt.private.match_listing').MatchListing
local Prompt = require('wincent.commandt.private.prompt').Prompt

local current_finder = nil -- Reference to avoid premature garbage collection.
local match_listing = nil
local prompt = nil

-- Reverses `list` in place.
local reverse = function(list)
  local i = 1
  local j = #list
  while i < j do
    list[i], list[j] = list[j], list[i]
    i = i + 1
    j = j - 1
  end
end

ui.show = function(finder, options)
  -- TODO validate options
  current_finder = finder
  assert(current_finder) -- Avoid Lua warning about unused local.
  match_listing = MatchListing.new({
    height = options.height,
    -- margin = 10,
    position = options.position,
    selection_highlight = options.selection_highlight,
  })
  match_listing:show()

  local results = nil
  local selected = nil
  prompt = Prompt.new({
    -- margin = 10,
    on_change = function(query)
      results = finder.run(query)
      if #results == 0 then
        selected = nil
      else
        if options.order == 'reverse' then
          reverse(results)
          selected = #results
        else
          selected = 1
        end
      end
      match_listing:update(results, { selected = selected })
    end,
    -- TODO: rename all "on" callbacks to use an underscore
    on_next = function()
      if results and #results then
        selected = math.min(selected + 1, #results)
        match_listing:select(selected)
      end
    end,
    on_previous = function()
      if results and #results then
        selected = math.max(selected - 1, 1)
        match_listing:select(selected)
      end
    end,
    -- TODO: decide whether we want an `index`, a string, or just to base it off
    -- our notion of current selection
    on_select = function()
      if results and #results then
        if match_listing then
          match_listing:close()
          match_listing = nil
        end
        if prompt then
          prompt:close()
          prompt = nil
        end
        finder.select(results[selected])
      end
    end,
    position = options.position,
  })
  prompt:show()
end

return ui
