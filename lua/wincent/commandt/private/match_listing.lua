-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local match_listing = {}

local Window = require('wincent.commandt.private.window').Window
local merge = require('wincent.commandt.private.merge')

local border_height = 2
local prompt_height = 1 + border_height

local MatchListing = {}

local mt = {
  __index = MatchListing,
}

function MatchListing.new(options)
  options = merge({
    height = 15,
    margin = 0,
    position = 'bottom',
    selection_highlight = 'PMenuSel',
  }, options or {})
  -- TODO: validate options
  local m = {
    _height = options.height,
    _margin = options.margin,
    _position = options.position,
    _lines = nil,
    _results = nil,
    _selected = nil,
    _selection_highlight = options.selection_highlight,
    _window = nil,
  }
  setmetatable(m, mt)
  return m
end

function MatchListing:close()
  if self._window then
    self._window:close()
  end
end

function MatchListing:select(selected)
  assert(type(selected) == 'number')
  assert(selected > 0)
  assert(selected <= #self._lines)
  if self._window then
    local selection = '  ' .. self._lines[self._selected]:sub(3)
    self._window:replace_line(selection, self._selected)
    self._window:unhighlight_line(self._selected)

    self._selected = selected
    selection = '> ' .. self._lines[self._selected]:sub(3)
    self._window:replace_line(selection, selected)
    self._window:highlight_line(selected)
  end
end

function MatchListing:show()
  local bottom = nil
  local top = nil
  if self._position == 'center' then
    local available_height = vim.o.lines - vim.o.cmdheight
    local used_height = 15 -- note we need to know how high the match listing is going to be
      + 2 -- match listing border
      + 3 -- our height
    local remaining_height = available_height - used_height -- TODO deal with overflow
    top = math.floor(remaining_height / 2) + 3 -- prompt height
  elseif self._position == 'bottom' then
    bottom = prompt_height
  else
    top = prompt_height
  end

  -- TODO: deal with other options, like reverse
  if self._window == nil then
    self._window = Window.new({
      bottom = bottom,
      filetype = 'CommandTMatchListing',
      height = self._height,
      margin = self._margin,
      on_close = function()
        -- print('got on_close for match listing')
        self._window = nil
        -- TODO: shouldn't really get this first, but close prompt
      end,
      on_leave = function()
        -- print('got on_leave for match listing')
      end,
      on_resize = function()
        if self._results then
          -- Cause paddings to be re-rendered.
          self:update(self._results, { selected = self._selected })
        end
      end,
      selection_highlight = self._selection_highlight,
      title = '',
      top = top,
    })
  end
  self._window:show()
end

function MatchListing:update(results, options)
  self._selected = options.selected
  self._results = results
  if self._window then
    local width = self._window:width() or vim.o.columns
    self._lines = {}
    for i, result in ipairs(results) do
      local prefix = i == self._selected and '> ' or '  '
      local line = nil

      -- Right pad so that selection highlighting is shown across full width.
      if width < 104 then
        if #result > 99 then
          -- No padding needed.
          line = prefix .. result
        else
          line = prefix .. string.format('%-' .. (width - #prefix) .. 's', result)
        end
      else
        -- Avoid: "invalid option" caused by format argument > 99.
        line = prefix .. string.format('%-99s', result)
        local diff = width - line:len()
        if diff > 0 then
          line = line .. string.rep(' ', diff)
        end
      end

      table.insert(self._lines, line)
    end
    self._window:unhighlight()
    self._window:replace_lines(self._lines, { adjust_height = true })
    if self._selected then
      self._window:highlight_line(self._selected)
    end
  end
end

match_listing.MatchListing = MatchListing

return match_listing
