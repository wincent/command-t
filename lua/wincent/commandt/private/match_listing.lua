-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local match_listing = {}

local Window = require('wincent.commandt.private.window').Window
local merge = require('wincent.commandt.private.merge')
local sub = require('wincent.commandt.private.sub')

local border_height = 2
local prompt_height = 1 + border_height

local MatchListing = {}

local mt = {
  __index = MatchListing,
}

function MatchListing.new(options)
  options = merge({
    border = { '', '', '', ' ', '', '', '', ' ' },
    height = 15,
    icons = true,
    margin = 0,
    position = 'bottom',
    selection_highlight = 'PmenuSel',
    truncate = 'middle',
  }, options or {})
  -- TODO: validate options
  local m = {
    _border = options.border,
    _height = options.height,
    _icons = options.icons,
    _margin = options.margin,
    _position = options.position,
    _lines = nil,
    _results = nil,
    _selected = nil,
    _selection_highlight = options.selection_highlight,
    _truncate = options.truncate,
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

function MatchListing:icon_getter()
  if self._icons == true and _G.MiniIcons then
    return function(name)
      return _G.MiniIcons.get('file', name)
    end
  elseif type(self._icons) == 'function' then
    return self._icons
  end
end

-- Unicode-aware `len` implementation.
local function len(str)
  return vim.str_utfindex(str, 'utf-32')
end

local format_line = function(line, width, selected, truncate, get_icon)
  local prefix = selected and '> ' or '  '

  local icon = get_icon and get_icon(line)
  local icon_length = 0
  if icon then
    icon_length = len(icon .. '  ')
    prefix = prefix .. icon .. '  '
  end

  -- Sanitize some control characters, plus blackslashes.
  line = line
    :gsub('\\', '\\\\')
    :gsub('\b', '\\b')
    :gsub('\f', '\\f')
    :gsub('\n', '\\n')
    :gsub('\r', '\\r')
    :gsub('\t', '\\t')
    :gsub('\v', '\\v')

  if len(line) + len(prefix) < width then
    -- Line fits without trimming.
  elseif len(line) < (5 + icon_length) then
    -- Line is so short that adding an ellipsis is not practical.
  elseif truncate == true or truncate == 'true' or truncate == 'middle' then
    local half = math.floor((width - 2) / 2)
    local left = sub(line, 1, half - 2 + width % 2)
    local right = sub(line, 2 - half)
    line = left .. '...' .. right
  elseif truncate == 'beginning' then
    line = '...' .. sub(line, -width + len(prefix) + 3)
  elseif truncate == false or truncate == 'false' or truncate == 'end' then
    -- Fall through; truncation will happen before the final `return`.
  end

  -- Right pad so that selection highlighting is shown across full width.
  if width < 102 and len(line) > 99 then
    -- No padding needed.
    line = prefix .. line
  else
    line = prefix .. line
    local diff = width - len(line)
    if diff > 0 then
      line = line .. string.rep(' ', diff)
    end
  end

  -- Trim to make sure we never wrap.
  return sub(line, 1, width)
end

function MatchListing:select(selected)
  assert(type(selected) == 'number')
  assert(selected > 0)
  assert(selected <= #self._results)
  if self._window then
    local width = self._window:width() or vim.o.columns -- BUG: width may be cached/stale

    local get_icon = self:icon_getter()
    local previous_selection = format_line(self._results[self._selected], width, false, self._truncate, get_icon)
    self._window:replace_line(previous_selection, self._selected)
    self._window:unhighlight_line(self._selected)

    self._selected = selected
    local new_selection = format_line(self._results[self._selected], width, true, self._truncate, get_icon)
    self._window:replace_line(new_selection, self._selected)
    self._window:highlight_line(self._selected)
  end
end

function MatchListing:show()
  local bottom = nil
  local top = nil
  if self._position == 'center' then
    local available_height = vim.o.lines - vim.o.cmdheight
    local used_height = self._height -- note we need to know how high the match listing is going to be
      + 2 -- match listing border
      + 3 -- our height
    local remaining_height = math.max(1, available_height - used_height)
    top = math.floor(remaining_height / 2) + 3 -- prompt height
  elseif self._position == 'bottom' then
    bottom = prompt_height
  else
    top = prompt_height
  end

  -- TODO: deal with other options, like reverse
  if self._window == nil then
    self._window = Window.new({
      border = self._border,
      bottom = bottom,
      description = 'CommandT [match listing]',
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
    local get_icon = self:icon_getter()
    self._lines = {}
    for i, result in ipairs(results) do
      local selected = i == self._selected
      local line = format_line(result, width, selected, self._truncate, get_icon)
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
