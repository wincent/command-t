-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local copy = require('wincent.commandt.private.copy')
local is_integer = require('wincent.commandt.private.is_integer')
local merge = require('wincent.commandt.private.merge')

local commandt = {}

commandt.buffer_finder = function()
  -- TODO: refactor to avoid duplication
  local ui = require('wincent.commandt.private.ui')
  local options = commandt.options()
  local finder = require('wincent.commandt.private.finders.buffer')(options)
  ui.show(finder, merge(options, { name = 'buffer' }))
end

commandt.file_finder = function(arg)
  local directory = vim.trim(arg)
  local ui = require('wincent.commandt.private.ui')
  local options = commandt.options()
  local finder = require('wincent.commandt.private.finders.file')(directory, options)
  ui.show(finder, merge(options, { name = 'file' }))
end

commandt.help_finder = function()
  -- TODO: refactor to avoid duplication
  local ui = require('wincent.commandt.private.ui')
  local options = commandt.options()
  local finder = require('wincent.commandt.private.finders.help')(options)
  ui.show(finder, merge(options, { name = 'help' }))
end

local default_options = {
  height = 15,

  -- Note that because of the way we merge mappings recursively, you can _add_
  -- or _replace_ a mapping easily, but to _remove_ it you have to assign it to
  -- `false` (`nil` won't work, because Lua will just skip over it).
  mappings = {
    i = {
      ['<C-j>'] = 'next',
      ['<C-k>'] = 'previous',
      ['<CR>'] = 'select',
      ['<Down>'] = 'next',
      ['<Up>'] = 'previous',
    },
    n = {
      ['<C-j>'] = 'next',
      ['<C-k>'] = 'previous',
      ['<CR>'] = 'select',
      ['<Down>'] = 'next',
      ['<Esc>'] = 'close', -- Only in normal mode by default.
      ['<Up>'] = 'previous',
    },
  },
  margin = 10,
  order = 'forward', -- 'forward', 'reverse'.
  position = 'center', -- 'bottom', 'center', 'top'.
  selection_highlight = 'PMenuSel',
  threads = nil, -- Let heuristic apply.
}

local _options = copy(default_options)

commandt.options = function()
  return copy(_options)
end

commandt.setup = function(options)
  if vim.g.command_t_loaded == 1 then
    error('commandt.setup(): Lua setup was called too late, after Ruby plugin setup has already run')
  elseif vim.g.CommandTPreferredImplementation == 'ruby' then
    print('commandt.setup(): was called, but g:CommandTPreferredImplementation is set to "ruby"')
    return
  else
    vim.g.CommandTPreferredImplementation = 'lua'
  end

  _options = merge(_options, options or {})

  if not is_integer(_options.margin) or _options.margin < 0 then
    error('commandt.setup(): `margin` must be a non-negative integer')
  end
  if _options.order ~= 'forward' and _options.order ~= 'reverse' then
    error("commandt.setup(): `order` must be 'forward' or 'reverse'")
  end
  if _options.position ~= 'bottom' and _options.position ~= 'center' and _options.position ~= 'top' then
    error("commandt.setup(): `position` must be 'bottom', 'center' or 'top'")
  end
  if _options.selection_highlight ~= nil and type(_options.selection_highlight) ~= 'string' then
    error('commandt.setup(): `selection_highlight` must be a string')
  end
end

commandt.watchman_finder = function(arg)
  local directory = vim.trim(arg)
  local ui = require('wincent.commandt.private.ui')
  local options = commandt.options()
  local finder = require('wincent.commandt.private.finders.watchman')(directory, options)
  ui.show(finder, merge(options, { name = 'watchman' }))
end

return commandt
