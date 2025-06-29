-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

-- Convenience wrapper around Neovim floating windows.
--
-- Manages a floating window and associated buffer, and provides methods for
-- positioning, updating, setting a title etc.

local is_integer = require('wincent.commandt.private.is_integer')
local merge = require('wincent.commandt.private.merge')
local types = require('wincent.commandt.private.options.types')
local validate = require('wincent.commandt.private.validate')

local Window = {}

local mt = {
  __index = Window,
}

local schema = {
  kind = 'table',
  keys = {
    border = types.border,
    bottom = {
      kind = 'number',
      optional = true,
      meta = function(context)
        if not is_integer(context.bottom) or context.bottom < 0 then
          context.bottom = 0
          return '`bottom` must be a non-negative integer'
        end
      end,
    },
    buftype = {
      kind = { one_of = { 'nofile', 'prompt' } },
    },
    description = { kind = 'string', optional = true },
    filetype = { kind = 'string', optional = true },
    height = types.height,
    margin = types.margin,
    on_change = { kind = 'function', optional = true },
    on_close = { kind = 'function', optional = true },
    on_leave = { kind = 'function', optional = true },
    on_resize = { kind = 'function', optional = true },
    position = {
      kind = { one_of = { 'bottom', 'center', 'top' } },
    },
    prompt = { kind = 'string' },
    selection_highlight = { kind = 'string' },
    title = { kind = 'string' },
    top = {
      kind = 'number',
      optional = true,
      meta = function(context)
        if not is_integer(context.top) or context.top < 0 then
          context.top = 0
          return '`top` must be a non-negative integer'
        end
      end,
    },
  },
  meta = function(context, report)
    if
      (type(context.bottom) == 'number' and context.top ~= nil)
      or (type(context.top) == 'number' and context.bottom ~= nil)
    then
      context.bottom = nil
      report('cannot set both `bottom` and `top`')
    end
    if context.bottom == nil and context.top == nil then
      context.top = 0
      report('must provide one of `bottom` or `top`')
    end
  end,
}

local validate_options = function(options)
  local errors = validate('', {}, options, schema, {})
  if #errors > 0 then
    error('Window.new(): ' .. errors[1])
  end
end

function Window.new(options)
  options = merge({
    border = nil,
    bottom = nil,
    buftype = 'nofile', -- Also, 'prompt'.
    description = nil,
    filetype = nil,
    height = 1,
    margin = 0,
    on_change = nil,
    on_close = nil,
    on_leave = nil,
    on_resize = nil,
    position = 'top',
    prompt = '> ', -- Has no effect unless `buftype` is 'prompt'.
    selection_highlight = 'PmenuSel',
    title = 'Command-T', -- Set to '' to suppress.
    top = nil,
  }, options)
  validate_options(options)
  local w = {
    _border = options.border,
    _bottom = options.bottom,
    _buftype = options.buftype,
    _description = options.description,
    _filetype = options.filetype,
    _height = options.height,
    _main_buffer = nil,
    _main_window = nil,
    _margin = options.margin,
    _namespace = vim.api.nvim_create_namespace(''),
    _on_change = options.on_change,
    _on_close = options.on_close,
    _on_leave = options.on_leave,
    _on_resize = options.on_resize,
    _padded_title = options.title ~= '' and (' ' .. options.title .. ' ') or '',
    _position = options.position,
    _prompt = options.prompt,
    _resize_autocmd = nil,
    _selection_highlight = options.selection_highlight,
    _title = options.title,
    _top = options.top,
    _width = nil,
  }
  setmetatable(w, mt)
  return w
end

function Window:close()
  if self._main_window then
    vim.api.nvim_win_close(self._main_window, true)
    self._main_window = nil
  end
end

-- For debuggability.
function Window:description()
  if self._description ~= nil then
    return self._description
  else
    local trimmed = vim.trim(self._padded_title)
    if trimmed == '' then
      return 'commandt.Window'
    else
      return trimmed
    end
  end
end

-- Focus the window and enter insert mode, ready to receive input.
function Window:focus()
  -- TODO: if not shown, show first automatically?, then...
  vim.api.nvim_set_current_win(self._main_window)
  vim.cmd('startinsert')
end

function Window:highlight_line(index)
  if self._main_window then
    vim.api.nvim_win_set_cursor(self._main_window, { index, 0 })
  end
  if self._main_buffer then
    vim.api.nvim_buf_set_extmark(
      self._main_buffer,
      self._namespace,
      index - 1, -- line (0-indexed)
      0, -- col_start
      {
        end_col = #vim.api.nvim_buf_get_lines(self._main_buffer, index - 1, index, false)[1],
        hl_group = self._selection_highlight,
      }
    )
  end
end

function Window:imap(lhs, rhs, options)
  self:map('i', lhs, rhs, options)
end

function Window:map(modes, lhs, rhs, options)
  if self._main_buffer then
    options = merge({ buffer = self._main_buffer }, options or {})
    if type(lhs) == 'string' then
      lhs = { lhs }
    end
    for _, l in ipairs(lhs) do
      vim.keymap.set(modes, l, rhs, options)
    end
  end
end

function Window:nmap(lhs, rhs, options)
  self:map('n', lhs, rhs, options)
end

function Window:replace_line(line, index)
  if self._main_buffer ~= nil then
    vim.api.nvim_buf_set_lines(
      self._main_buffer,
      index - 1, -- start (0-based)
      index, -- end (end-exclusive)
      false, -- strict indexing
      { line } -- replacement lines
    )
  end
end

function Window:replace_lines(lines, options)
  if self._main_buffer ~= nil then
    vim.api.nvim_buf_set_lines(
      self._main_buffer,
      0, -- start
      -1, -- end
      false, -- strict indexing
      lines -- replacement lines
    )
  end
  if options and options.adjust_height then
    -- TODO: rather than overwriting height, distinguish maxheight and height
    -- maxheight will stay fixed, but height can fluctuate with content
    self._height = math.max(1, #lines)
    self:_reposition()
  end
end

function Window:set_title(title)
  self._title = title
  self._padded_title = title ~= '' and (' ' .. title .. ' ') or ''
  self:_reposition()
  if self._main_window then
    vim.api.nvim_win_set_config(self._main_window, {
      title = self._position ~= 'bottom' and { { self._padded_title, 'FloatBorder' } } or nil,
      footer = self._position == 'bottom' and { { self._padded_title, 'FloatBorder' } } or nil,
    })
  end
end

function Window:show()
  if self._main_buffer == nil then
    self._main_buffer = vim.api.nvim_create_buf(
      false, -- listed = false
      true -- scratch = true
    )
    if self._main_buffer == 0 then
      error('Window:show(): nvim_create_buf() failed')
    end
    local ps1 = self._prompt or '> '
    vim.api.nvim_buf_set_name(self._main_buffer, self:description() .. ' (main)')
    vim.api.nvim_set_option_value('modifiable', true, { buf = self._main_buffer })
    vim.api.nvim_set_option_value('buftype', self._buftype, { buf = self._main_buffer })
    if self._buftype == 'prompt' then
      vim.fn.prompt_setprompt(self._main_buffer, ps1)
    end
    if self._on_change then
      local callback = function()
        -- Should be able to use `vim.fn.prompt_getprompt(self._main_buffer)`,
        -- but it only returns the prompt prefix for some reason...
        local query = vim.api.nvim_get_current_line():sub(#ps1 + 1)
        self._on_change(query)
        vim.api.nvim_set_option_value('modified', false, { buf = self._main_buffer })
      end
      vim.api.nvim_create_autocmd('TextChanged', {
        buffer = self._main_buffer,
        callback = callback,
      })
      vim.api.nvim_create_autocmd('TextChangedI', {
        buffer = self._main_buffer,
        callback = callback,
      })
    end
    self._resize_autocmd = vim.api.nvim_create_autocmd('VimResized', {
      callback = function()
        -- One autocmd will handle both title and main repositioning.
        self:_reposition()
        if self._on_resize then
          self._on_resize()
        end
      end,
      group = vim.api.nvim_create_augroup('CommandTWindow', { clear = false }),
    })
    vim.api.nvim_create_autocmd('BufWipeout', {
      buffer = self._main_buffer,
      callback = function()
        self._main_buffer = nil
      end,
    })
  end
  local position = self:_calculate_position()
  if self._main_window == nil then
    self._main_window = vim.api.nvim_open_win(
      self._main_buffer,
      false, -- enter = false
      merge({
        border = self._border,
        focusable = false,
        noautocmd = true,
        relative = 'editor',
        style = 'minimal',
        title = self._position ~= 'bottom' and { { self._padded_title, 'FloatBorder' } } or nil,
        footer = self._position == 'bottom' and { { self._padded_title, 'FloatBorder' } } or nil,
      }, position)
    )
    if self._main_window == 0 then
      error('Window:show(): nvim_open_win() failed')
    end
    self._width = position.width
    -- TODO: maybe watch for buffer destruction too
    -- then nvim_win_close
    vim.api.nvim_create_autocmd('WinClosed', {
      buffer = self._main_buffer,
      nested = true,
      once = true,
      callback = function()
        self._main_window = nil
        if self._main_buffer then
          vim.api.nvim_buf_delete(self._main_buffer, { force = true })
          self._main_buffer = nil
        end
        if self._resize_autocmd ~= nil then
          vim.api.nvim_del_autocmd(self._resize_autocmd)
          self._resize_autocmd = nil
        end
        if self._on_close then
          self._on_close()
        end
      end,
    })
    if self._on_leave then
      vim.api.nvim_create_autocmd('WinLeave', {
        buffer = self._main_buffer,
        callback = self._on_leave,
        once = true,
        nested = true,
      })
    end

    -- Note we do this _after_ putting buffer in window, so that `ftplugin`
    -- files can set window-level options based on `'filetype'` instead of just
    -- buffer-level ones.
    if self._filetype ~= nil then
      vim.api.nvim_set_option_value('filetype', self._filetype, { buf = self._main_buffer })
    end

    -- TODO: decide whether I need to clear lines here.
    vim.api.nvim_buf_set_lines(
      self._main_buffer,
      0, -- start
      -1, -- end
      false, -- strict indexing = false
      {} -- replacement lines
    )
  end
end

-- Remove highlighting from a specific line.
function Window:unhighlight_line(index)
  if self._main_buffer then
    vim.api.nvim_buf_clear_namespace(
      self._main_buffer,
      self._namespace,
      index - 1, -- start (0-indexed)
      index -- end (end-exclusive)
    )
  end
end

-- Clear highlighting from entire buffer.
function Window:unhighlight()
  if self._main_buffer then
    vim.api.nvim_buf_clear_namespace(
      self._main_buffer,
      self._namespace,
      0, -- start (0-indexed)
      -1 -- end (end-exclusive)
    )
  end
end

function Window:width()
  return self._width
end

function Window:_reposition()
  local position = merge(
    self:_calculate_position(),
    -- Need `relative` to avoid:
    --
    --    non-float cannot have 'row' [C]: in function 'nvim_win_set_config'
    --
    -- See: https://github.com/neovim/neovim/issues/18368
    { relative = 'editor' }
  )
  if self._main_window ~= nil then
    vim.api.nvim_win_set_config(self._main_window, position)
    self._width = position.width
  end
end

-- Return a clamped `value` (restricted to range `minimum, maximum`).
local clamp = function(value, minimum, maximum)
  return math.max(minimum, math.min(value, maximum))
end

-- Tries to fit window within existing dimensions. If the editor window is too
-- small, then shrinks to fit inside it. If it is still too small, all bets are
-- off, although Neovim will draw what it can inside the viewport.
function Window:_calculate_position()
  local editor_width = vim.o.columns
  local border_width = 2
  local minimum_width = 1
  local width = math.max(
    border_width + minimum_width,
    border_width + #self._padded_title,
    editor_width - 2 * self._margin
  ) - border_width
  local col = math.floor((editor_width - width + border_width) / 2)
  local editor_height = vim.o.lines
  local border_height = 2
  local usable_height = editor_height - vim.o.cmdheight
  if type(self._top) == 'number' then
    local height = clamp(self._height, 1, usable_height - self._top - border_height)
    return {
      col = col,
      height = height,
      row = self._top,
      width = width,
    }
  elseif type(self._bottom) == 'number' then
    local height = clamp(self._height, 1, usable_height - self._bottom - border_height)
    return {
      col = col,
      height = height,
      row = usable_height - self._bottom - height - border_height,
      width = width,
    }
  end
end

return Window
