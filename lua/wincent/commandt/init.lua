-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local merge = require('wincent.commandt.private.merge')

local commandt = {}

local chooser_buffer = nil
local chooser_selected_index = nil
local chooser_window = nil

-- require('wincent.commandt.private.finder') -- TODO: decide whether we need this, or
-- only scanners
-- local scanner = require('wincent.commandt.private.scanner')

-- print('scanner ' .. vim.inspect(scanner.buffer.get()))

-- TODO: make mappings configurable again
local mappings = {
  ['<C-j>'] = "<Cmd>lua require'wincent.commandt'.select_next()<CR>",
  ['<C-k>'] = "<Cmd>lua require'wincent.commandt'.select_previous()<CR>",
  ['<Down>'] = "<Cmd>lua require'wincent.commandt'.select_next()<CR>",
  ['<Up>'] = "<Cmd>lua require'wincent.commandt'.select_previous()<CR>",
}

local set_up_mappings = function()
  for lhs, rhs in pairs(mappings) do
    vim.api.nvim_set_keymap('c', lhs, rhs, { silent = true })
  end
end

local tear_down_mappings = function()
  for lhs, rhs in pairs(mappings) do
    if vim.fn.maparg(lhs, 'c') == rhs then
      vim.api.nvim_del_keymap('c', lhs)
    end
  end
end

commandt.buffer_finder = function()
  -- TODO: just call the method and see it not segfault
  if true then
    return
  end
end

commandt.cmdline_changed = function(char)
  if char == ':' then
    local line = vim.fn.getcmdline()
    local _, _, variant, query = string.find(line, '^%s*KommandT(%a*)%f[%A]%s*(.-)%s*$')
    if query ~= nil then
      if variant == '' or variant == 'Buffer' then
        set_up_mappings()
        local height = math.floor(vim.o.lines / 2) -- TODO make height somewhat dynamic
        local width = vim.o.columns
        if chooser_window == nil then
          chooser_buffer = vim.api.nvim_create_buf(false, true)
          chooser_window = vim.api.nvim_open_win(chooser_buffer, false, {
            col = 0,
            row = height,
            focusable = false,
            relative = 'editor',
            style = 'minimal',
            width = width,
            height = vim.o.lines - height - 2,
          })
          vim.api.nvim_win_set_option(chooser_window, 'wrap', false)
          vim.api.nvim_win_set_option(chooser_window, 'winhl', 'Normal:Question')
          vim.cmd('redraw')
        end
        return
      end
    end
  end
  tear_down_mappings()
end

commandt.cmdline_enter = function()
  chooser_selected_index = nil
end

commandt.cmdline_leave = function()
  if chooser_window ~= nil then
    vim.api.nvim_win_close(chooser_window, true)
    chooser_window = nil
  end
  tear_down_mappings()
end

local matcher = nil
-- Attempt to work around potential bug where scanner could get garbage
-- collected as soon as it falls out of scope...
local scanner = nil

commandt.demo = function(query)
  local lib = require('wincent.commandt.private.lib')
  if matcher == nil then
    local options = {}
    -- scanner = require('wincent.commandt.private.scanner.buffer').scanner()
    -- scanner = require('wincent.commandt.private.scanner.help').scanner()
    -- scanner = require('wincent.commandt.private.scanner.watchman').scanner(os.getenv('PWD'))
    -- scanner = require('wincent.commandt.private.scanner.git').scanner()
    -- scanner = require('wincent.commandt.private.scanner.rg').scanner()
    scanner = require('wincent.commandt.private.scanner.find').scanner()
    matcher = lib.commandt_matcher_new(scanner, options)
  end

  local results = lib.commandt_matcher_run(matcher, query)
  local strings = {}
  for i = 0, results.count - 1 do
    local str = results.matches[i]
    table.insert(strings, ffi.string(str.contents, str.length))
  end
  return strings
end

commandt.file_finder = function(arg)
  local directory = vim.trim(arg)

  -- TODO: need to figure out what the semantics should be here as far as
  -- optional directory parameter goes
end

commandt.prompt = function()
  local match_listing = require('wincent.commandt.private.match_listing')
  match_listing.show({
    height = commandt._options.height,
    position = commandt._options.position,
  })
  require('wincent.commandt.private.prompt').show({
    onchange = function(query)
      local results = commandt.demo(query)
      match_listing.update(results)
    end,
    position = commandt._options.position,
  })
end

commandt.select_next = function() end

commandt.select_previous = function() end

-- TODO: make public accessor version of this (that will deal with a copy)
commandt._options = {
  height = 15,
  order = 'reverse',
  position = 'bottom',
}

commandt.setup = function(options)
  -- TODO add setup customization here
  options = merge({
    height = 15,
    order = 'reverse', -- 'forward', 'reverse'.
    position = 'bottom', -- 'bottom', 'center', 'top'.
  }, options or {})

  if options.order ~= 'forward' and options.order ~= 'reverse' then
    error("commandt.setup(): `order` must be 'forward' or 'reverse'")
  end
  if options.position ~= 'bottom' and options.position ~= 'center' and options.position ~= 'top' then
    error("commandt.setup(): `position` must be 'bottom', 'center' or 'top'")
  end
  commandt.options.position = options.position
end

return commandt
