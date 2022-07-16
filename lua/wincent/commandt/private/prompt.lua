-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local prompt = {}

local buffer = nil
local window = nil

prompt.show = function(options)
  -- TODO: merge
  if buffer == nil then
    buffer = vim.api.nvim_create_buf(
      false, -- listed
      true -- scratch
    )
    if buffer == 0 then
      error('wincent.commandt.prompt.show(): nvim_create_buf() failed')
    end
    local ps1 = '> '
    vim.api.nvim_buf_set_option(buffer, 'buftype', 'prompt')
    vim.fn.prompt_setprompt(buffer, ps1)
    vim.api.nvim_buf_set_option(buffer, 'filetype', 'CommandTPrompt')
    vim.api.nvim_create_autocmd('TextChanged', {
      buffer = buffer,
      callback = function()
        if options and options.onchange then
          -- Should be able to use `prompt_getprompt()`, but it only returns the
          -- prompt prefix for some reason...
          -- local query = vim.fn.prompt_getprompt(buffer)
          local query = vim.api.nvim_get_current_line():sub(#ps1 + 1)
          options.onchange(query)
        end
      end,
    })
    vim.api.nvim_create_autocmd('TextChangedI', {
      buffer = buffer,
      callback = function()
        if options and options.onchange then
          local query = vim.api.nvim_get_current_line():sub(#ps1 + 1)
          options.onchange(query)
        end
      end,
    })
  end
  if window == nil then
    local width = vim.o.columns
    window = vim.api.nvim_open_win(
      buffer,
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
    if window == 0 then
      error('wincent.commandt.prompt.show(): nvim_open_win() failed')
    end
    -- TODO: maybe watch for buffer destruction too
    -- TODO: watch for resize events
    vim.api.nvim_create_autocmd('WinClosed', {
      once = true,
      callback = function()
        window = nil
      end,
    })
    vim.api.nvim_win_set_option(window, 'wrap', false)
  end
  vim.api.nvim_buf_set_lines(
    buffer,
    0, -- start
    -1, -- end
    false, -- strict indexing
    {} -- replacement lines
  )
  vim.api.nvim_set_current_win(window)
  vim.api.nvim_feedkeys(
    'i', -- keys
    'n', -- don't remap
    true -- escape K_SPECIAL bytes in keys
  )
end

return prompt
