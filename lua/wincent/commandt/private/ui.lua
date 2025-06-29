-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local UI = {}

local MatchListing = require('wincent.commandt.private.match_listing')
local Prompt = require('wincent.commandt.private.prompt')
local Settings = require('wincent.commandt.private.settings')
local validate = require('wincent.commandt.private.validate')
local types = require('wincent.commandt.private.options.types')

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

function UI.new()
  local self = {
    candidate_count = nil,
    cmdline_enter_autocmd = nil,
    current_finder = nil,
    current_window = nil,
    match_listing = nil,
    on_close = nil,
    on_open = nil,
    prompt = nil,
    results = nil,
    selected = nil,
    settings = Settings.new(),
  }
  setmetatable(self, { __index = UI })
  return self
end

-- TODO: reasons to delete a window
-- 1. [DONE] user explicitly closes it with ESC
-- 2. [DONE] user explicitly accepts a selection
-- 3. [DONE] user navigates out of the window (WinLeave)
-- 4. [DONE] user uses a Vim command to close the window or the buffer
-- (we get this "for free" kind of thanks to WinLeave happening as soon as you
-- do anything that would move you out)

function UI:_close()
  -- Restore global settings.
  self.settings.hlsearch = nil

  if self.match_listing then
    self.match_listing:close()
    self.match_listing = nil
  end
  if self.prompt then
    self.prompt:close()
    self.prompt = nil
  end
  if self.cmdline_enter_autocmd ~= nil then
    vim.api.nvim_del_autocmd(self.cmdline_enter_autocmd)
    self.cmdline_enter_autocmd = nil
  end
  if self.current_window then
    -- Due to autocommand nesting, and the fact that we call `close()` for
    -- `WinLeave`, `WinClosed`, or us calling `:close()`, we have to be careful
    -- to avoid infinite recursion here, by setting `current_window` to `nil`
    -- _before_ calling `nvim_set_current_win()`:
    local win = self.current_window
    self.current_window = nil
    vim.api.nvim_set_current_win(win)
  end
  if self.on_close then
    self.on_close()
    self.on_close = nil
  end
end

function UI:_open(ex_command)
  self:_close()
  if self.results and #self.results > 0 then
    local result = self.results[self.selected]
    if self.on_open then
      result = self.on_open(result)
    end

    -- Defer, to give autocommands a chance to run.
    vim.defer_fn(function()
      self.current_finder.open(result, ex_command)
    end, 0)
  end
  self.on_open = nil
end

local schema = {
  kind = 'table',
  keys = {
    mode = types.mode,
    name = { kind = 'string' },
    on_close = { kind = 'function', optional = true },
    on_open = { kind = 'function', optional = true },
  },
}

local validate_config = function(config)
  local errors = validate('', {}, config, schema, {})
  if #errors > 0 then
    error('UI:show(): ' .. errors[1])
  end
end

--- Display the Command-T UI, consisting of a Prompt window and a MatchListing
--- window.
---
--- @param finder any
--- @param options any Top-level Command-T options.
--- @param config any `UI`-specific config.
function UI:show(finder, options, config)
  validate_config(config)
  self.current_finder = finder

  self.current_window = vim.api.nvim_get_current_win()

  self.on_close = config.on_close
  self.on_open = config.on_open

  -- Temporarily override global settings.
  -- For now just 'hlsearch', but may add more later (see
  -- ruby/command-t/lib/command-t/match_window.rb)
  self.settings.hlsearch = false

  -- Work around an autocommand bug. We don't reliably get `WinClosed` events,
  -- or if we do, our call to `nvim_del_autocmd()` doesn't always clean up for
  -- us. So, we add some window-related autocommands to a group which we always
  -- reset every time we show a new UI.
  vim.api.nvim_create_augroup('CommandTWindow', { clear = true })

  local border = options.match_listing.border ~= 'winborder' and options.match_listing.border or nil
  self.match_listing = MatchListing.new({
    border = border,
    height = options.height,
    icons = config.mode ~= 'virtual' and options.match_listing.icons or false,
    margin = options.margin,
    position = options.position,
    selection_highlight = options.selection_highlight,
    truncate = options.match_listing.truncate,
  })
  self.match_listing:show()

  self.results = nil
  self.selected = nil
  border = options.prompt.border ~= 'winborder' and options.prompt.border or nil
  self.prompt = Prompt.new({
    border = border,
    height = options.height,
    mappings = options.mappings,
    margin = options.margin,
    name = config.name,
    on_change = function(query)
      self.results, self.candidate_count = self.current_finder.run(query)
      if #self.results > 0 or self.candidate_count > 0 then
        -- Once we've proved a finder works, we don't ever want to use fallback.
        self.current_finder.fallback = nil
      elseif self.current_finder.fallback then
        self.current_finder, name = self.current_finder.fallback()
        self.prompt.name = name or 'fallback'
        self.results = self.current_finder.run(query)
      end
      if #self.results == 0 then
        self.selected = nil
      else
        if options.order == 'reverse' then
          reverse(self.results)
          self.selected = #self.results
        else
          self.selected = 1
        end
      end
      self.match_listing:update(self.results, { selected = self.selected })
    end,
    on_leave = function()
      self:_close()
    end,
    -- TODO: decide whether we want an `index`, a string, or just to base it off
    -- our notion of current selection
    on_open = function(ex_command)
      self:_open(ex_command)
    end,
    on_select = function(choice)
      if self.results and #self.results > 0 then
        if choice.absolute then
          if choice.absolute > 0 then
            self.selected = math.min(choice.absolute, #self.results)
          elseif choice.absolute < 0 then
            self.selected = math.max(#self.results + choice.absolute + 1, 1)
          else -- Absolute "middle".
            self.selected = math.min(math.floor(#self.results / 2) + 1, #self.results)
          end
        elseif choice.relative then
          if choice.relative > 0 then
            self.selected = math.min(self.selected + choice.relative, #self.results)
          else
            self.selected = math.max(self.selected + choice.relative, 1)
          end
        end
        self.match_listing:select(self.selected)
      end
    end,
    position = options.position,
  })
  self.prompt:show()

  if self.cmdline_enter_autocmd == nil then
    self.cmdline_enter_autocmd = vim.api.nvim_create_autocmd('CmdlineEnter', {
      callback = function()
        self:_close()
      end,
    })
  end
end

return UI
