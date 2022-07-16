-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local prompt = {}

local window = require('wincent.commandt.private.window')

local input_buffer = nil
local input_window = nil
local title_buffer = nil
local title_window = nil

prompt.show = function(options)
  -- TODO: merge options
  if input_buffer == nil then
    input_buffer = vim.api.nvim_create_buf(
      false, -- listed
      true -- scratch
    )
    if input_buffer == 0 then
      error('wincent.commandt.private.prompt.show(): nvim_create_buf() failed')
    end
    local ps1 = '> '
    vim.api.nvim_buf_set_option(input_buffer, 'buftype', 'prompt')
    vim.fn.prompt_setprompt(input_buffer, ps1)
    vim.api.nvim_buf_set_option(input_buffer, 'filetype', 'CommandTPrompt')
    vim.api.nvim_create_autocmd('TextChanged', {
      buffer = input_buffer,
      callback = function()
        if options and options.onchange then
          -- Should be able to use `prompt_getprompt()`, but it only returns the
          -- prompt prefix for some reason...
          -- local query = vim.fn.prompt_getprompt(input_buffer)
          local query = vim.api.nvim_get_current_line():sub(#ps1 + 1)
          options.onchange(query)
        end
      end,
    })
    vim.api.nvim_create_autocmd('TextChangedI', {
      buffer = input_buffer,
      callback = function()
        if options and options.onchange then
          local query = vim.api.nvim_get_current_line():sub(#ps1 + 1)
          options.onchange(query)
        end
      end,
    })
  end
  if input_window == nil then
    local width = vim.o.columns
    input_window = vim.api.nvim_open_win(
      input_buffer,
      true, -- enter
      {
        border = 'single',
        col = 0,
        focusable = false,
        height = 1,
        noautocmd = true,
        relative = 'editor',
        row = vim.o.lines - 3,
        style = 'minimal',
        width = width,
      }
    )
    if input_window == 0 then
      error('wincent.commandt.private.prompt.show(): nvim_open_win() failed')
    end
    -- TODO: maybe watch for buffer destruction too
    -- TODO: watch for resize events
    vim.api.nvim_create_autocmd('WinClosed', {
      once = true,
      callback = function()
        input_window = nil
      end,
    })
    vim.api.nvim_win_set_option(input_window, 'wrap', false)
  end
  vim.api.nvim_buf_set_lines(
    input_buffer,
    0, -- start
    -1, -- end
    false, -- strict indexing
    {} -- replacement lines
  )
  -- This is verbose; make utility methods...
  if title_buffer == nil then
    title_buffer = vim.api.nvim_create_buf(
      false, -- listed
      true -- scratch
    )
    if title_buffer == 0 then
      error('wincent.commandt.private.prompt.show(): nvim_create_buf() failed')
    end
    vim.api.nvim_buf_set_option(title_buffer, 'buftype', 'nofile')
    vim.api.nvim_buf_set_option(title_buffer, 'filetype', 'CommandTTitle')
  end
  local prompt_title = ' Command-T [type] '
  if title_window == nil then
    title_window = vim.api.nvim_open_win(
      title_buffer,
      false, -- enter
      {
        col = 3,
        focusable = false,
        height = 1,
        noautocmd = true,
        relative = 'editor',
        row = vim.o.lines - 4,
        style = 'minimal',
        width = #prompt_title,
        win = prompt_window,
        zindex = 60, -- Default for floats is 50
      }
    )
    if title_window == 0 then
      error('wincent.commandt.private.prompt.show(): nvim_open_win() failed')
    end
  end
  vim.api.nvim_buf_set_lines(
    title_buffer,
    0, -- start
    -1, -- end
    false, -- strict indexing
    { prompt_title } -- TODO: put actual type
  )
  vim.api.nvim_set_current_win(input_window)
  vim.cmd('startinsert')
  -- vim.api.nvim_feedkeys(
  --   'i', -- keys
  --   'n', -- don't remap
  --   true -- escape K_SPECIAL bytes in keys
  -- )
end

return prompt
