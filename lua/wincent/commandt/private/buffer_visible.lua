-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local buffer_visible = nil

-- `vim.fn.bufwinnr()` doesn't see windows in other tabs, meaning we open them
-- again instead of switching to the other tab; but `vim.fn.bufname()` sees
-- hidden buffers, and if we try to open one of those, we get an unwanted split.
-- So, this function does some additional work to check whether `buffer` is
-- _really_ visible.
buffer_visible = function(buffer)
  -- TODO: port this to use lower-level nvim APIs, if there are any that could
  -- be used here...
  if vim.fn.bufwinnr('^' .. buffer .. '$') ~= -1 then
    -- Buffer is open in current tab.
    return true
  elseif vim.fn.bufexists(buffer) == 0 then
    -- Buffer has never been opened, or if it was, it was wiped.
    return false
  elseif vim.fn.bufloaded(buffer) == 0 then
    -- Buffer is not shown in a window nor is it hidden.
    return false
  elseif vim.fn.buflisted(buffer) == 0 then
    -- Buffer is not listed.
    return false
  else
    -- Check to see if buffer is hidden (has 'h' in the `:ls` output).
    local bufnr = vim.fn.bufnr(buffer)
    local ls_buffers = vim.fn.execute('ls')
    for _, line in ipairs(vim.split(ls_buffers, '\n', { trimempty = true })) do
      -- Trim first so " 1" vs "10" doesn't ruin our whitespace-based splitting.
      local components = vim.split(vim.trim(line), '%s+')
      if components[1] == bufnr then
        return components[2]:find('h') == nil
      end
    end

    return true
  end
end

return buffer_visible
