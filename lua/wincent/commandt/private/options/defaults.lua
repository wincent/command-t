-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local sbuffer = require('wincent.commandt.sbuffer')

local Defaults = {}

local mt = {
  __index = Defaults,
}

function Defaults.new()
  local instance = {
    _options = nil,
  }

  instance._options = {
    always_show_dot_files = false,
    finders = {
      buffer = require('wincent.commandt.private.finders.buffer'),
      command = require('wincent.commandt.private.finders.command'),
      fd = require('wincent.commandt.private.finders.fd'),
      find = require('wincent.commandt.private.finders.find'),
      git = require('wincent.commandt.private.finders.git'),
      help = require('wincent.commandt.private.finders.help'),
      history = require('wincent.commandt.private.finders.history'),
      jump = require('wincent.commandt.private.finders.jump'),
      line = require('wincent.commandt.private.finders.line'),
      rg = require('wincent.commandt.private.finders.rg'),
      search = require('wincent.commandt.private.finders.search'),
      tag = require('wincent.commandt.private.finders.tag'),
    },
    height = 15,

    -- If nil, will infer from Neovim's `'ignorecase'`.
    ignore_case = function()
      return vim.o.ignorecase
    end,

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
        ['<C-w>'] = '<C-S-w>',
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
    match_listing = {
      border = { '', '', '', '│', '┘', '─', '└', '│' }, -- 'double', 'none', 'rounded', 'shadow', 'single', 'solid', 'winborder', or a list of strings.
      icons = true,
      truncate = 'middle',
    },
    never_show_dot_files = false,
    order = 'forward', -- 'forward', 'reverse'.
    position = 'center', -- 'bottom', 'center', 'top'.
    prompt = {
      border = { '┌', '─', '┐', '│', '┤', '─', '├', '│' }, -- 'double', 'none', 'rounded', 'shadow', 'single', 'solid', 'winborder', or a list of strings.
    },
    open = sbuffer,
    root_markers = { '.git', '.hg', '.svn', '.bzr', '_darcs' },
    scanners = {
      fd = {
        max_files = 0,
      },
      file = {
        max_files = 0,
      },
      find = {
        max_files = 0,
      },
      git = {
        max_files = 0,
        submodules = true,
        untracked = false,
      },
      rg = {
        max_files = 0,
      },
      tag = {
        include_filenames = false,
      },
    },
    selection_highlight = 'PmenuSel',

    -- If nil, will infer from Neovim's `'smartcase'`.
    smart_case = function()
      return vim.o.smartcase
    end,

    threads = nil, -- Let heuristic apply.
    traverse = 'none', -- 'file', 'pwd' or 'none'.
  }
  setmetatable(instance, mt)
  return instance
end

function Defaults:clone(options)
  local copy = require('wincent.commandt.private.copy')
  local result = copy(self._options)

  -- Swap border definitions if `position = 'bottom'` is set, and reverse order.
  if type(options) == 'table' and options.position == 'bottom' then
    result.match_listing.border = self._options.prompt.border
    result.prompt.border = self._options.match_listing.border
    result.order = 'reverse'
  end

  return result
end

-- Singleton instance.
local defaults = Defaults.new()

return defaults
