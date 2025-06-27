-- SPDX-FileCopyrightText: Copyright 2025-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local force_dot_files = require('wincent.commandt.private.options.force_dot_files')
local keys = require('wincent.commandt.private.keys')

local jump = {
  candidates = function(_directory, _options)
    local filename_candidates = {}
    local bufnr_candidates = {}

    -- For all tab pages' windows' jumplists' entries, grab their `filename`
    -- or `bufnr` properties.
    for _, tabpage in ipairs(vim.api.nvim_list_tabpages()) do
      for _, winnr in ipairs(vim.api.nvim_tabpage_list_wins(tabpage)) do
        local jumplist = vim.fn.getjumplist(winnr, tabpage)
        for _, jump in ipairs(jumplist[1]) do
          if jump.filename and jump.filename ~= '' then
            filename_candidates[jump.filename] = true
          elseif jump.bufnr then
            bufnr_candidates[jump.bufnr] = true
          end
        end
      end
    end

    -- For each `bufnr`, attempt to convert it into a `filename`.
    for bufnr, _ in pairs(bufnr_candidates) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        local filename = vim.api.nvim_buf_get_name(bufnr)
        filename_candidates[filename] = true
      end
    end

    local relative_candidates = {}
    local cwd = vim.fn.getcwd()

    for filename, _ in pairs(filename_candidates) do
      if filename ~= '' then
        filename = vim.fn.expand(filename)
        if vim.fn.filereadable(filename) == 1 then
          -- Convert absolute paths to relative if they're under cwd.
          if filename:match('^/') and filename:find(cwd, 1, true) == 1 then
            filename = filename:sub(#cwd + 2)
          end
          relative_candidates[filename] = true
        end
      end
    end

    local candidates = keys(relative_candidates)
    table.sort(candidates)
    return candidates
  end,
  options = force_dot_files,
}

return jump
