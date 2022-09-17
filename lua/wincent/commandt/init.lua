-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local concat = require('wincent.commandt.private.concat')
local contains = require('wincent.commandt.private.contains')
local copy = require('wincent.commandt.private.copy')
local is_integer = require('wincent.commandt.private.is_integer')
local keys = require('wincent.commandt.private.keys')
local merge = require('wincent.commandt.private.merge')

local commandt = {}

local open = function(buffer, command)
  buffer = vim.fn.fnameescape(buffer)
  local is_visible = require('wincent.commandt.private.buffer_visible')(buffer)
  if is_visible then
    -- In order to be useful, `:sbuffer` needs `vim.o.switchbuf = 'usetab'`.
    vim.cmd('sbuffer ' .. buffer)
  else
    vim.cmd(command .. ' ' .. buffer)
  end
end

local help_opened = false

local default_options = {
  always_show_dot_files = false,
  finders = {
    -- Returns the list of paths currently loaded into buffers.
    buffer = {
      candidates = function()
        -- TODO: don't include unlisted buffers unless user wants them (need some way
        -- for them to signal that)
        local handles = vim.api.nvim_list_bufs()
        local paths = {}
        for _, handle in ipairs(handles) do
          if vim.api.nvim_buf_is_loaded(handle) then
            local name = vim.api.nvim_buf_get_name(handle)
            if name ~= '' then
              local relative = vim.fn.fnamemodify(name, ':~:.')
              table.insert(paths, relative)
            end
          end
        end
        return paths
      end,
    },
    find = {
      command = function(directory)
        if vim.startswith(directory, './') then
          directory = directory:sub(3, -1)
        end
        if directory ~= '' and directory ~= '.' then
          directory = vim.fn.shellescape(directory)
        end
        local drop = 0
        if directory == '' or directory == '.' then
          -- Drop 2 characters because `find` will prefix every result with "./",
          -- making it look like a dotfile.
          directory = '.'
          drop = 2
          -- TODO: decide what to do if somebody passes '..' or similar, because that
          -- will also make the results get filtered out as though they were dotfiles.
          -- I may end up needing to do some fancy, separate micromanagement of
          -- prefixes and let the matcher operate on paths without prefixes.
        end
        -- TODO: support max depth, dot directory filter etc
        local command = 'find -L ' .. directory .. ' -type f -print0 2> /dev/null'
        return command, drop
      end,
      fallback = true,
    },
    git = {
      command = function(directory, options)
        if directory ~= '' then
          directory = vim.fn.shellescape(directory)
        end
        local command = 'git ls-files --exclude-standard --cached -z'
        if options.submodules then
          command = command .. ' --recurse-submodules'
        elseif options.untracked then
          command = command .. ' --others'
        end
        if directory ~= '' then
          command = command .. ' -- ' .. directory
        end
        command = command .. ' 2> /dev/null'
        return command
      end,
      fallback = true,
    },
    help = {
      candidates = function()
        -- Neovim doesn't provide an easy way to get a list of all help tags.
        -- `tagfiles()` only shows the tagfiles for the current buffer, so you need
        -- to already be in a buffer of `'buftype'` `help` for that to work.
        -- Likewise, `taglist()` only shows tags that apply to the current file
        -- type, and `:tag` has the same restriction.
        --
        -- So, we look for "doc/tags" files at every location in the `'runtimepath'`
        -- and try to manually parse it.
        local helptags = {}
        local tagfiles = vim.api.nvim_get_runtime_file('doc/tags', true)
        for _, tagfile in ipairs(tagfiles) do
          if vim.fn.filereadable(tagfile) then
            for _, tag in ipairs(vim.fn.readfile(tagfile)) do
              local _, _, tag_text = tag:find('^%s*(%S+)%s+')
              if tag_text ~= nil then
                table.insert(helptags, tag_text)
              end
            end
          end
        end
        -- TODO: memoize this? (ie. add `memoize = true`)?
        return helptags
      end,
      open = function(item, kind)
        local command = 'help'
        if kind == 'split' then
          -- Split is the default, so for this finder, we abuse "split" mode to do
          -- the opposite of the default, using tricks noted in `:help help-curwin`.
          --
          -- See also: https://github.com/vim/vim/issues/7534
          if not help_opened then
            vim.cmd([[
              silent noautocmd keepalt help
              silent noautocmd keepalt helpclose
            ]])
            help_opened = true
          end
          if vim.fn.empty(vim.fn.getcompletion(item, 'help')) == 0 then
            vim.cmd('silent noautocmd keepalt edit ' .. vim.o.helpfile)
          end
        elseif kind == 'tabedit' then
          command = 'tab help'
        elseif kind == 'vsplit' then
          command = 'vertical help'
        end

        -- E434 "Can't find tag pattern" is innocuous, so swallow it. For more
        -- context, see: https://github.com/autozimu/LanguageClient-neovim/pull/731
        vim.cmd('try | ' .. command .. ' ' .. item .. ' | catch /E434/ | endtry')
      end,
    },
    line = {
      candidates = function()
        local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
        local result = {}
        for i, line in ipairs(lines) do
          -- Skip blank/empty lines.
          if not line:match('^%s*$') then
            table.insert(result, vim.trim(line) .. ':' .. tostring(i))
          end
        end
        return result
      end,
      open = function(item)
        -- Extract line number from (eg) "some line contents:100".
        local suffix = string.find(item, '%d+$')
        local index = tonumber(item:sub(suffix))
        vim.api.nvim_win_set_cursor(0, { index, 0 })
      end,
    },
    rg = {
      command = function(directory)
        if vim.startswith(directory, './') then
          directory = directory:sub(3, -1)
        end
        if directory ~= '' and directory ~= '.' then
          directory = vim.fn.shellescape(directory)
        end
        local drop = 0
        if directory == '.' then
          drop = 2
        end
        local command = 'rg --files --null'
        if #directory > 0 then
          command = command .. ' ' .. directory
        end
        command = command .. ' 2> /dev/null'
        return command, drop
      end,
      fallback = true,
    },
  },
  height = 15,
  ignore_case = nil, -- If nil, will infer from Neovim's `'ignorecase'`.

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
  never_show_dot_files = false,
  order = 'forward', -- 'forward', 'reverse'.
  position = 'center', -- 'bottom', 'center', 'top'.
  open = open,
  scanners = {
    git = {
      submodules = true,
      untracked = false,
    },
  },
  selection_highlight = 'PMenuSel',
  smart_case = nil, -- If nil, will infer from Neovim's `'smartcase'`.
  threads = nil, -- Let heuristic apply.
}

-- Have to add some of these explicitly otherwise the ones with `nil` defaults
-- won't come through (eg. `ignore_case` etc).
local allowed_options = concat(keys(default_options), {
  'ignore_case',
  'smart_case',
  'threads',
})

commandt.default_options = function()
  return copy(default_options)
end

commandt.file_finder = function(directory)
  directory = vim.trim(directory)
  if directory == '' then
    directory = '.'
  end
  local ui = require('wincent.commandt.private.ui')
  local options = commandt.options()
  local finder = require('wincent.commandt.private.finders.file')(directory, options)
  ui.show(finder, merge(options, { name = 'file' }))
end

commandt.finder = function(name, directory)
  local options = commandt.options()
  local config = options.finders[name]
  if config == nil then
    error('commandt.finder(): no finder registered with name ' .. tostring(name))
  end
  if directory ~= nil then
    directory = vim.trim(directory)
  end
  local finder = nil
  options.open = function(item, kind)
    if config.open then
      config.open(item, kind)
    else
      commandt.open(item, kind)
    end
  end
  if config.candidates then
    finder = require('wincent.commandt.private.finders.list')(directory, config.candidates, options)
  else
    finder = require('wincent.commandt.private.finders.command')(directory, config.command, options)
  end
  if config.fallback then
    finder.fallback = require('wincent.commandt.private.finders.fallback')(finder, directory, options)
  end
  local ui = require('wincent.commandt.private.ui')
  ui.show(finder, merge(options, { name = name }))
end

-- "Smart" open that will switch to an already open window containing the
-- specified `buffer`, if one exists; otherwise, it will open a new window using
-- `command` (which should be one of `edit`, `tabedit`, `split`, or `vsplit`).
commandt.open = open

local _options = copy(default_options)

commandt.options = function()
  return copy(_options)
end

commandt.setup = function(options)
  local errors = {}

  if vim.g.CommandTPreferredImplementation == 'ruby' then
    table.insert(errors, '`commandt.setup()` was called, but `g:CommandTPreferredImplementation` is set to "ruby"')
  else
    vim.g.CommandTPreferredImplementation = 'lua'
  end

  options = options or {}

  _options = merge(_options, options)

  -- Inferred from Neovim settings if not explicitly set.
  if _options.ignore_case == nil then
    _options.ignore_case = vim.o.ignorecase
  end
  if _options.smart_case == nil then
    _options.smart_case = vim.o.smartcase
  end

  -- Helper functions for validating options.
  local report = function(message)
    table.insert(errors, message)
  end
  local last = function(list)
    return list[#list]
  end
  local split_option = function(option)
    local segments = {}
    -- Append trailing '.' to make it easier to split.
    for segment in string.gmatch(option .. '.', '([%a%d_]+)%.') do
      table.insert(segments, segment)
    end
    return segments
  end
  local pick = function(option, value, pop)
    pop = pop ~= nil and pop or 0
    local segments = split_option(option)
    local result = value
    for i, segment in ipairs(segments) do
      if i <= #segments - pop then
        assert(type(result) == 'table')
        result = result[segment]
      end
    end
    return result
  end
  local reset = function(option, actual, defaults)
    actual = actual ~= nil and actual or _options
    defaults = defaults ~= nil and defaults or default_options
    actual = pick(option, actual, 1)
    actual[last(split_option(option))] = copy(pick(option, defaults))
  end
  local optional_function = function(option, actual, defaults)
    actual = actual ~= nil and actual or _options
    defaults = defaults ~= nil and defaults or default_options
    local value = pick(option, actual)
    if value ~= nil and type(value) ~= 'function' then
      report(string.format('`%s` must be a function or nil', option))
      reset(option, actual, defaults)
    end
  end
  local optional_function_or_string = function(option, actual, defaults)
    actual = actual ~= nil and actual or _options
    defaults = defaults ~= nil and defaults or default_options
    local value = pick(option, actual)
    if value ~= nil and type(value) ~= 'function' and type(value) ~= 'string' then
      report(string.format('`%s` must be a function or string or nil', option))
      reset(option, actual, defaults)
    end
  end
  local optional_function_or_table = function(option, actual, defaults)
    actual = actual ~= nil and actual or _options
    defaults = defaults ~= nil and defaults or default_options
    local value = pick(option, actual)
    if value ~= nil and type(value) ~= 'function' and type(value) ~= 'table' then
      report(string.format('`%s` must be a function or table or nil', option))
      reset(option, actual, defaults)
    end
  end
  local require_boolean = function(option, actual, defaults)
    actual = actual ~= nil and actual or _options
    defaults = defaults ~= nil and defaults or default_options
    if type(pick(option, actual)) ~= 'boolean' then
      report(string.format('`%s` must be true or false', option))
      reset(option, actual, defaults)
    end
  end
  local require_one_of = function(option, choices, actual, defaults)
    actual = actual ~= nil and actual or _options
    defaults = defaults ~= nil and defaults or default_options
    local description = ''
    local picked = pick(option, actual)
    for i, choice in ipairs(choices) do
      if picked == choice then
        return
      end
      if i == 1 then
        description = "'" .. choice .. "'"
      elseif i == #choices then
        description = description .. " or '" .. choice .. "'"
      else
        description = description .. ", '" .. choice .. "'"
      end
    end
    report(string.format('`%s` must be %s', option, description))
    reset(option, actual, defaults)
  end
  local require_positive_integer = function(option, actual, defaults)
    actual = actual ~= nil and actual or _options
    defaults = defaults ~= nil and defaults or default_options
    local picked = pick(option, actual)
    if not is_integer(picked) or picked < 0 then
      report(string.format('`%s` must be a non-negative integer', option))
      reset(option, actual, defaults)
    end
  end
  local require_string = function(option, actual, defaults)
    actual = actual ~= nil and actual or _options
    defaults = defaults ~= nil and defaults or default_options
    local picked = pick(option, actual)
    if type(picked) ~= 'string' then
      report(string.format('`%s` must be a string', option))
      reset(option, actual, defaults)
    end
  end
  local require_table = function(option, actual, defaults)
    actual = actual ~= nil and actual or _options
    defaults = defaults ~= nil and defaults or default_options
    local picked = pick(option, actual)
    if type(picked) ~= 'table' then
      report(string.format('`%s` must be a table', option))
      reset(option, actual, defaults)
    end
  end

  for k, _ in pairs(options) do
    -- `n` is small, so not worried about `O(n)` check.
    if not contains(allowed_options, k) then
      -- TODO: suggest near-matches for misspelled option names
      report('unrecognized option: ' .. k)
    end
  end

  require_boolean('always_show_dot_files')
  require_boolean('never_show_dot_files')
  if _options.always_show_dot_files == true and _options.never_show_dot_files == true then
    report('`always_show_dot_files` and `never_show_dot_files` should not both be true')
    reset('always_show_dot_files')
    reset('never_show_dot_files')
  end
  require_boolean('ignore_case')
  require_positive_integer('margin')
  require_one_of('order', { 'forward', 'reverse' })
  require_one_of('position', { 'bottom', 'center', 'top' })
  require_table('scanners')
  require_table('scanners.git')
  require_boolean('scanners.git.submodules')
  require_boolean('scanners.git.untracked')
  if _options.scanners.git.submodules == true and _options.scanners.git.untracked == true then
    report('`scanners.git.submodules` and `scanners.git.untracked` should not both be true')
    reset('scanners.git.submodules')
    reset('scanners.git.untracked')
  end
  require_string('selection_highlight')
  require_boolean('smart_case')

  for name, finder in pairs(options.finders or {}) do
    optional_function_or_table('finders.' .. name .. '.candidates', nil, {
      finders = {
        [name] = {
          command = 'true',
        },
      },
    })
    optional_function_or_string('finders.' .. name .. '.command', nil, {
      finders = {
        [name] = {
          command = 'true',
        },
      },
    })
    optional_function('finders.' .. name .. '.open', nil, {
      finders = {
        [name] = {},
      },
    })
    -- TODO: complain if passed `candidates` _and_ `command`.
    for k, _ in pairs(finder) do
      if not contains({ 'candidates', 'command', 'open' }, k) then
        report(string.format('unrecognized option in `finders.%s`: %s)', name, k))
      end
    end
  end

  if
    not pcall(function()
      local lib = require('wincent.commandt.private.lib') -- We can require it.
      lib.epoch() -- We can use it.
    end)
  then
    table.insert(errors, 'unable to load and use C library - run `:checkhealth wincent.commandt`')
  end

  if #errors > 0 then
    table.insert(errors, 1, 'commandt.setup():')
    for i, message in ipairs(errors) do
      local indent = i == 1 and '' or '  '
      errors[i] = { indent .. message .. '\n', 'WarningMsg' }
    end
    vim.api.nvim_echo(errors, true, {})
  end
end

commandt.watchman_finder = function(directory)
  directory = vim.trim(directory)
  local ui = require('wincent.commandt.private.ui')
  local options = commandt.options()
  local finder = require('wincent.commandt.private.finders.watchman')(directory, options)
  ui.show(finder, merge(options, { name = 'watchman' }))
end

return commandt
