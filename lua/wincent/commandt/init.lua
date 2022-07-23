-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local concat = require('wincent.commandt.private.concat')
local contains = require('wincent.commandt.private.contains')
local copy = require('wincent.commandt.private.copy')
local is_integer = require('wincent.commandt.private.is_integer')
local keys = require('wincent.commandt.private.keys')
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
  always_show_dot_files = false,
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
  never_show_dotfiles = false,
  order = 'forward', -- 'forward', 'reverse'.
  position = 'center', -- 'bottom', 'center', 'top'.
  selection_highlight = 'PMenuSel',
  threads = nil, -- Let heuristic apply.
}

-- Have to add some of these explicitly otherwise the ones with `nil` defaults
-- won't come through (eg. `threads`).
local allowed_options = concat(keys(default_options), { 'threads' })

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

  local errors = {}
  options = options or {}
  for k, _ in pairs(options) do
    -- `n` is small, so not worried about `O(n)` check.
    if not contains(allowed_options, k) then
      -- TODO: suggest near-matches for misspelled option names
      table.insert(errors, '  unrecognized option: ' .. k)
    end
  end

  _options = merge(_options, options)

  if _options.always_show_dot_files == true and _options.never_show_dot_files == true then
    table.insert(errors, '`always_show_dot_files` and `never_show_dot_files` should not both be true')
  end
  if not is_integer(_options.margin) or _options.margin < 0 then
    table.insert(errors, '`margin` must be a non-negative integer')
  end
  if _options.order ~= 'forward' and _options.order ~= 'reverse' then
    table.insert(errors, "`order` must be 'forward' or 'reverse'")
  end
  if _options.position ~= 'bottom' and _options.position ~= 'center' and _options.position ~= 'top' then
    table.insert(errors, "`position` must be 'bottom', 'center' or 'top'")
  end
  if _options.selection_highlight ~= nil and type(_options.selection_highlight) ~= 'string' then
    table.insert(errors, '`selection_highlight` must be a string')
  end

  if #errors > 0 then
    table.insert(errors, 1, 'commandt.setup():')
    for i, message in ipairs(errors) do
      errors[i] = { message .. '\n', 'WarningMsg' }
    end
    vim.api.nvim_echo(errors, true, {})
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
