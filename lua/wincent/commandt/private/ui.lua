-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ui = {}

local MatchListing = require('wincent.commandt.private.match_listing').MatchListing
local Prompt = require('wincent.commandt.private.prompt').Prompt
local Settings = require('wincent.commandt.private.settings')

local candidate_count = nil
local cmdline_enter_autocmd = nil
local current_finder = nil -- Reference to avoid premature garbage collection.
local current_window = nil
local match_listing = nil
local on_close = nil
local on_open = nil
local prompt = nil
local results = nil
local selected = nil
local settings = Settings.new()

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

-- TODO: reasons to delete a window
-- 1. [DONE] user explicitly closes it with ESC
-- 2. [DONE] user explicitly accepts a selection
-- 3. [DONE] user navigates out of the window (WinLeave)
-- 4. [DONE] user uses a Vim command to close the window or the buffer
-- (we get this "for free" kind of thanks to WinLeave happening as soon as you
-- do anything that would move you out)

local close = function()
  -- Restore global settings.
  settings.hlsearch = nil

  if match_listing then
    match_listing:close()
    match_listing = nil
  end
  if prompt then
    prompt:close()
    prompt = nil
  end
  if cmdline_enter_autocmd ~= nil then
    vim.api.nvim_del_autocmd(cmdline_enter_autocmd)
    cmdline_enter_autocmd = nil
  end
  if current_window then
    -- Due to autocommand nesting, and the fact that we call `close()` for
    -- `WinLeave`, `WinClosed`, or us calling `:close()`, we have to be careful
    -- to avoid infinite recursion here, by setting `current_window` to `nil`
    -- _before_ calling `nvim_set_current_win()`:
    local win = current_window
    current_window = nil
    vim.api.nvim_set_current_win(win)
  end
  if on_close then
    on_close()
    on_close = nil
  end
end

ui.open = function(kind)
  close()
  if results and #results > 0 then
    local result = results[selected]
    if on_open then
      result = on_open(result)
    end

    -- Defer, to give autocommands a chance to run.
    vim.defer_fn(function()
      current_finder.open(result, kind)
    end, 0)
  end
  on_open = nil
end

ui.show = function(finder, options)
  -- TODO validate options
  current_finder = finder

  current_window = vim.api.nvim_get_current_win()

  on_close = options.on_close
  on_open = options.on_open

  -- Temporarily override global settings.
  -- For now just 'hlsearch', but may add more later (see
  -- ruby/command-t/lib/command-t/match_window.rb)
  settings.hlsearch = false

  -- Work around an autocommand bug. We don't reliably get `WinClosed` events,
  -- or if we do, our call to `nvim_del_autocmd()` doesn't always clean up for
  -- us. So, we add some window-related autocommands to a group which we always
  -- reset every time we show a new UI.
  vim.api.nvim_create_augroup('CommandTWindow', { clear = true })

  match_listing = MatchListing.new({
    border = options.match_listing.border,
    height = options.height,
    icons = options.kind ~= 'virtual' and options.match_listing.icons or false,
    margin = options.margin,
    position = options.position,
    selection_highlight = options.selection_highlight,
    truncate = options.match_listing.truncate,
  })
  match_listing:show()

  results = nil
  selected = nil
  prompt = Prompt.new({
    border = options.prompt.border,
    height = options.height,
    mappings = options.mappings,
    margin = options.margin,
    name = options.name,
    on_change = function(query)
      results, candidate_count = current_finder.run(query)
      if #results > 0 or candidate_count > 0 then
        -- Once we've proved a finder works, we don't ever want to use fallback.
        current_finder.fallback = nil
      elseif current_finder.fallback then
        current_finder, name = current_finder.fallback()
        prompt.name = name or 'fallback'
        results = current_finder.run(query)
      end
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
    on_leave = close,
    -- TODO: decide whether we want an `index`, a string, or just to base it off
    -- our notion of current selection
    on_open = ui.open,
    on_select = function(choice)
      if results and #results > 0 then
        if choice.absolute then
          if choice.absolute > 0 then
            selected = math.min(choice.absolute, #results)
          elseif choice.absolute < 0 then
            selected = math.max(#results + choice.absolute + 1, 1)
          else -- Absolute "middle".
            selected = math.min(math.floor(#results / 2) + 1, #results)
          end
        elseif choice.relative then
          if choice.relative > 0 then
            selected = math.min(selected + choice.relative, #results)
          else
            selected = math.max(selected + choice.relative, 1)
          end
        end
        match_listing:select(selected)
      end
    end,
    position = options.position,
  })
  prompt:show()

  if cmdline_enter_autocmd == nil then
    cmdline_enter_autocmd = vim.api.nvim_create_autocmd('CmdlineEnter', {
      callback = close,
    })
  end
end

return ui
