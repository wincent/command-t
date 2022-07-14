-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local match_listing = {}

local buffer = nil
local window = nil

match_listing.show = function()
  if buffer == nil then
    buffer = vim.api.nvim_create_buf(
      false, -- listed
      true -- scratch
    )
    if buffer == 0 then
      error('wincent.commandt.match_listing.show(): nvim_create_buf() failed')
    end
    vim.api.nvim_buf_set_option(buffer, 'filetype', 'CommandTMatchListing')
  end
  if window == nil then
    local width = vim.o.columns
    window = vim.api.nvim_open_win(
      buffer,
      false, -- enter
      {
        border = 'single',
        col = 0,
        focusable = false,
        height = vim.o.lines - 6,
        noautocmd = true,
        relative = 'editor',
        row = 0,
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
    { 'match', 'listing' } -- replacement lines
  )
end

match_listing.update = function(results)
  if buffer then
    vim.api.nvim_buf_set_lines(
      buffer,
      0, -- start
      -1, -- end
      false, -- strict indexing
      results -- replacement lines
    )
  end
end

return match_listing
