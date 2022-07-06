local help = {}

local helptags = nil

-- The joys of Vim "magic" regexps: `(`, `)`, and `+` need a backslash, but `*`
-- does not. I'm going to rewrite this using Lua patterns, but I want to commit
-- this just to reflect my indignation in the Git history.
local tag_regex = vim.regex('^\\s*\\(\\S\\+\\)\\s\\+')

-- Returns the list of helptags that can be opened with `:help {tag}`
--
-- Will return a cached value unless `force` is truthy (or there is no cached
-- value).
help.get = function(force)
  if helptags == nil or force then
    -- Neovim doesn't provide an easy way to get a list of all help tags.
    -- `tagfiles()` only shows the tagfiles for the current buffer, so you need
    -- to already be in a buffer of `'buftype'` `help` for that to work.
    -- Likewise, `taglist()` only shows tags that apply to the current file
    -- type, and `:tag` has the same restriction.
    --
    -- So, we look for "doc/tags" files at every location in the `'runtimepath'`
    -- and try to manually parse it.
    helptags = {}
    local tagfiles = vim.api.nvim_get_runtime_file('doc/tags', true)
    local handles = vim.api.nvim_list_bufs()
    local names = {}

    for _, tagfile in ipairs(tagfiles) do
      if vim.fn.filereadable(tagfile) then
        for _, tag in ipairs(vim.fn.readfile(tagfile)) do
          local start_index, end_index = tag_regex:match_str(tag)
          if start_index ~= nil then
            local tag_text = tag:sub(start_index, end_index - 1)
            table.insert(helptags, tag_text)
          end
        end
      end
    end
  end

  return helptags
end

return help
