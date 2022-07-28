-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local concat = require('wincent.commandt.private.concat')
local contains = require('wincent.commandt.private.contains')
local copy = require('wincent.commandt.private.copy')
local is_integer = require('wincent.commandt.private.is_integer')
local keys = require('wincent.commandt.private.keys')
local merge = require('wincent.commandt.private.merge')

local commandt = {}

local default_options = {
  always_show_dot_files = false,
  height = 15,
  ignore_case = nil, -- If nil, will infer from Neovim's `'ignorecase'`.
  smart_case = nil, -- If nil, will infer from Neovim's `'smartcase'`.

  -- Note that because of the way we merge mappings recursively, you can _add_
  -- or _replace_ a mapping easily, but to _remove_ it you have to assign it to
  -- `false` (`nil` won't work, because Lua will just skip over it).
  mappings = {
    i = {
      ['<C-a>'] = '<Home>',
      ['<C-c>'] = 'close',
      ['<C-e>'] = '<End>',
      ['<C-h>'] = '<Left>',
      ['<C-j>'] = 'select_next',
      ['<C-k>'] = 'select_previous',
      ['<C-l>'] = '<Right>',
      ['<C-n>'] = 'select_next',
      ['<C-p>'] = 'select_previous',
      ['<C-s>'] = 'open_split',
      ['<C-t>'] = 'open_tab',
      ['<C-v>'] = 'open_vsplit',
      ['<CR>'] = 'open',
      ['<Down>'] = 'select_next',
      ['<Up>'] = 'select_previous',
    },
    n = {
      ['<C-a>'] = '<Home>',
      ['<C-c>'] = 'close',
      ['<C-e>'] = '<End>',
      ['<C-h>'] = '<Left>',
      ['<C-j>'] = 'select_next',
      ['<C-k>'] = 'select_previous',
      ['<C-l>'] = '<Right>',
      ['<C-n>'] = 'select_next',
      ['<C-p>'] = 'select_previous',
      ['<C-s>'] = 'open_split',
      ['<C-t>'] = 'open_tab',
      ['<C-u>'] = 'clear', -- Not needed in insert mode.
      ['<C-v>'] = 'open_vsplit',
      ['<CR>'] = 'open',
      ['<Down>'] = 'select_next',
      ['<Esc>'] = 'close', -- Only in normal mode.
      ['<Up>'] = 'select_previous',
      ['H'] = 'select_first', -- Only in normal mode.
      ['M'] = 'select_middle', -- Only in normal mode.
      ['G'] = 'select_last', -- Only in normal mode.
      ['L'] = 'select_last', -- Only in normal mode.
      ['gg'] = 'select_first', -- Only in normal mode.
      ['j'] = 'select_next', -- Only in normal mode.
      ['k'] = 'select_previous', -- Only in normal mode.
    },
  },
  margin = 10,
  never_show_dotfiles = false,
  order = 'forward', -- 'forward', 'reverse'.
  position = 'center', -- 'bottom', 'center', 'top'.
  open = function(item, kind)
    commandt.open(item, kind)
  end,
  selection_highlight = 'PMenuSel',
  threads = nil, -- Let heuristic apply.
}

-- Have to add some of these explicitly otherwise the ones with `nil` defaults
-- won't come through (eg. `ignore_case` etc).
local allowed_options = concat(keys(default_options), {
  'ignore_case',
  'smart_case',
  'threads',
})

commandt.buffer_finder = function()
  -- TODO: refactor to avoid duplication
  local ui = require('wincent.commandt.private.ui')
  local options = commandt.options()
  local finder = require('wincent.commandt.private.finders.buffer')(options)
  ui.show(finder, merge(options, { name = 'buffer' }))
end

commandt.default_options = function()
  return copy(default_options)
end

commandt.file_finder = function(arg)
  local directory = vim.trim(arg)
  if directory == '' then
    directory = '.'
  end
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

-- "Smart" open that will switch to an already open window containing the
-- specified `buffer`, if one exists; otherwise, it will open a new window using
-- `command` (which should be one of `edit`, `tabedit`, `split`, or `vsplit`).
commandt.open = function(buffer, command)
  local is_visible = require('wincent.commandt.private.buffer_visible')(buffer)
  if is_visible then
    -- In order to be useful, `:sbuffer` needs `vim.o.switchbuf = 'usetab'`.
    vim.cmd('sbuffer ' .. buffer)
  else
    vim.cmd(command .. ' ' .. buffer)
  end
end

local _options = copy(default_options)

commandt.options = function()
  return copy(_options)
end

commandt.setup = function(options)
  local errors = {}

  if vim.g.command_t_loaded == 1 then
    -- May not be an error if you (for whatever reason) are calling `setup()`
    -- twice (ie. later on during a session), but it's presumed that if you're
    -- doing that, you know enough about what you're doing not to understand
    -- that this error message is nothing to worry about.
    table.insert(errors, '`commandt.setup()` was called after Ruby plugin setup has already run')
  elseif vim.g.CommandTPreferredImplementation == 'ruby' then
    table.insert(errors, '`commandt.setup()` was called, but `g:CommandTPreferredImplementation` is set to "ruby"')
  else
    vim.g.CommandTPreferredImplementation = 'lua'
  end

  options = options or {}
  for k, _ in pairs(options) do
    -- `n` is small, so not worried about `O(n)` check.
    if not contains(allowed_options, k) then
      -- TODO: suggest near-matches for misspelled option names
      table.insert(errors, 'unrecognized option: ' .. k)
    end
  end

  _options = merge(_options, options)

  -- Inferred from Neovim settings if not explicitly set.
  if _options.ignore_case == nil then
    _options.ignore_case = vim.o.ignorecase
  end
  if _options.smart_case == nil then
    _options.smart_case = vim.o.smartcase
  end

  if _options.always_show_dot_files == true and _options.never_show_dot_files == true then
    table.insert(errors, '`always_show_dot_files` and `never_show_dot_files` should not both be true')
  end
  if _options.ignore_case ~= true and _options.ignore_case ~= false then
    table.insert(errors, '`ignore_case` must be true or false')
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
  if _options.smart_case ~= true and _options.smart_case ~= false then
    table.insert(errors, '`smart_case` must be true or false')
  end

  if
    not pcall(function()
      local lib = require('wincent.commandt.private.lib') -- We can require it.
      lib.commandt_epoch() -- We can use it.
    end)
  then
    table.insert(errors, 'unable to load and use C library - run `:checkhealth wincent.commandt`')
  end

  if #errors > 0 then
    table.insert(errors, 1, 'commandt.setup():')
    for i, message in ipairs(errors) do
      local indent = i == 1 and '' or '  '
      errors[i] = { indent .. message .. '\n', 'WarningMsg' }
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
