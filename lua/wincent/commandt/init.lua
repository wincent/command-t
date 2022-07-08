-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local commandt = {}

local chooser_buffer = nil
local chooser_selected_index = nil
local chooser_window = nil

-- require('wincent.commandt.finder') -- TODO: decide whether we need this, or
-- only scanners
-- local scanner = require('wincent.commandt.scanner')

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
    vim.api.nvim_set_keymap('c', lhs, rhs, {silent = true})
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
  local lib = require('wincent.commandt.lib')
  if matcher == nil then
    local options = {}
    --[[local--]] scanner = require('wincent.commandt.scanner.help').scanner()
    --[[local--]] matcher = lib.commandt_matcher_new(scanner, options)
  end
  print('query: ' .. query)

  -- Using help scanner, a needle like "tag" returns a bunch of results (eg.
  -- `tag`, `-tag`, `:tag`, `tags` etc).
  -- local results = lib.commandt_matcher_run(matcher, "tag")
  -- local results = lib.commandt_matcher_run(matcher, "")
  local results = lib.commandt_matcher_run(matcher, query)
  local strings = {}
  print(results.count)
  for i = 0, results.count - 1 do
    local str = results.matches[i]
    table.insert(strings, ffi.string(str.contents, str.length))
  end
  print(vim.inspect(strings))
  return strings
end

commandt.file_finder = function(arg)
  local directory = vim.trim(arg)

  -- TODO: need to figure out what the semantics should be here as far as
  -- optional directory parameter goes
end

commandt.select_next = function()
end

commandt.select_previous = function()
end

return commandt
