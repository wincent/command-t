-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local merge = require('wincent.commandt.private.merge')

local commandt = {}

-- TODO: make mappings configurable again
local mappings = {
  ['<C-j>'] = "<Cmd>lua require'wincent.commandt'.select_next()<CR>",
  ['<C-k>'] = "<Cmd>lua require'wincent.commandt'.select_previous()<CR>",
  ['<Down>'] = "<Cmd>lua require'wincent.commandt'.select_next()<CR>",
  ['<Up>'] = "<Cmd>lua require'wincent.commandt'.select_previous()<CR>",
}

commandt.buffer_finder = function()
  -- TODO: refactor to avoid duplication
  local ui = require('wincent.commandt.private.ui')
  local finder = require('wincent.commandt.private.finders.buffer')()
  ui.show(finder, {
    height = commandt._options.height,
    name = 'buffer',
    order = commandt._options.order,
    position = commandt._options.position,
    selection_highlight = commandt._options.selection_highlight,
  })
end

commandt.file_finder = function(arg)
  local directory = vim.trim(arg)
  local ui = require('wincent.commandt.private.ui')
  local finder = require('wincent.commandt.private.finders.file')(directory)
  ui.show(finder, {
    height = commandt._options.height,
    name = 'file',
    order = commandt._options.order,
    position = commandt._options.position,
    selection_highlight = commandt._options.selection_highlight,
  })
end

commandt.help_finder = function()
  -- TODO: refactor to avoid duplication
  local ui = require('wincent.commandt.private.ui')
  local finder = require('wincent.commandt.private.finders.help')()
  ui.show(finder, {
    height = commandt._options.height,
    name = 'help',
    order = commandt._options.order,
    position = commandt._options.position,
    selection_highlight = commandt._options.selection_highlight,
  })
end

commandt.select_next = function() end

commandt.select_previous = function() end

-- TODO: make public accessor version of this (that will deal with a copy)
commandt._options = {
  height = 15,
  margin = 0,
  order = 'reverse',
  position = 'bottom',
  selection_highlight = 'PMenuSel',
  threads = nil,
}

commandt.setup = function(options)
  options = merge({
    height = 15,
    margin = 0,
    order = 'reverse', -- 'forward', 'reverse'.
    position = 'bottom', -- 'bottom', 'center', 'top'.
    selection_highlight = 'PMenuSel',
    threads = nil, -- Let heuristic apply.
  }, options or {})

  if options.order ~= 'forward' and options.order ~= 'reverse' then
    error("commandt.setup(): `order` must be 'forward' or 'reverse'")
  end
  if options.position ~= 'bottom' and options.position ~= 'center' and options.position ~= 'top' then
    error("commandt.setup(): `position` must be 'bottom', 'center' or 'top'")
  end
  commandt.options.position = options.position
  commandt.options.selection_highlight = options.selection_highlight
end

commandt.watchman_finder = function(arg)
  local directory = vim.trim(arg)
  local ui = require('wincent.commandt.private.ui')
  local finder = require('wincent.commandt.private.finders.watchman')(directory)
  ui.show(finder, {
    height = commandt._options.height,
    name = 'watchman',
    order = commandt._options.order,
    position = commandt._options.position,
    selection_highlight = commandt._options.selection_highlight,
  })
end

return commandt
