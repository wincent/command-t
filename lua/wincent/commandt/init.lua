-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local concat = require('wincent.commandt.private.concat')
local copy = require('wincent.commandt.private.copy')
local is_integer = require('wincent.commandt.private.is_integer')
local is_table = require('wincent.commandt.private.is_table')
local keys = require('wincent.commandt.private.keys')
local merge = require('wincent.commandt.private.merge')
local sub = require('wincent.commandt.private.sub')

local commandt = {}

--- "Smart" open that will switch to an already open window containing the
--- specified `buffer`, if one exists; otherwise, it will open a new window
--- using `command` (which should be one of `edit`, `tabedit`, `split`, or
--- `vsplit`).
---
--- @param buffer string
--- @param command 'edit' | 'split' | 'tabedit' | 'vsplit'
--- @return nil
local function smart_open(buffer, command)
  buffer = vim.fn.fnameescape(buffer)
  local is_visible = require('wincent.commandt.private.buffer_visible')(buffer)
  if is_visible then
    -- Note that, in order to be useful, `:sbuffer` needs
    -- `vim.o.switchbuf = 'usetab'` to be set.
    vim.cmd('sbuffer ' .. buffer)
  else
    vim.cmd(command .. ' ' .. buffer)
  end
end

local directory_stack = {}

--- Push a directory onto the stack.
---
--- @param directory string
--- @return nil
local function pushd(directory)
  table.insert(directory_stack, vim.uv.cwd())
  vim.fn.chdir(directory)
end

--- Pop a directory from the stack.
---
--- @return nil
local function popd()
  local directory = table.remove(directory_stack)
  if directory then
    vim.fn.chdir(directory)
  end
end

--- Common `on_directory` implementation that infers the appropriate directory
--- if none is explicitly provided.
---
--- @param directory string | nil
--- @return string
local function on_directory(directory)
  if directory == '' or directory == nil then
    return commandt._directory()
  else
    return directory
  end
end

local function relativize(directory, file)
  if directory ~= '' then
    return vim.fs.normalize(vim.fs.joinpath(directory, file))
  else
    return file
  end
end

-- Common `on_open` implementation used by several "command" finders that equips
-- them to deal with automatic directory changes caused by the `traverse`
-- setting.
local function on_open(item, kind, directory, opener)
  opener(relativize(directory, item), kind)
end

local help_opened = false

local options_spec = {
  kind = 'table',
  keys = {
    always_show_dot_files = { kind = 'boolean' },
    finders = {
      kind = 'table',
      values = {
        kind = 'table',
        keys = {
          candidates = {
            kind = {
              one_of = {
                { kind = 'function' },
                {
                  kind = 'list',
                  of = { kind = 'string' },
                },
              },
            },
            optional = true,
          },
          kind = {
            kind = {
              one_of = {
                'file',
                'virtual',
              },
            },
            optional = true,
          },
          on_close = {
            kind = 'function',
            optional = true,
          },
          on_directory = {
            kind = 'function',
            optional = true,
          },
          options = {
            kind = 'function',
            optional = true,
          },
          command = {
            kind = {
              one_of = {
                { kind = 'function' },
                { kind = 'string' },
              },
            },
            optional = true,
          },
          fallback = { kind = 'boolean', optional = true },
          max_files = {
            kind = {
              one_of = {
                { kind = 'function' },
                { kind = 'number' },
              },
            },
            optional = true,
          },
          open = { kind = 'function', optional = true },
        },
      },
      meta = function(t)
        local errors = {}
        if is_table(t) then
          for key, value in pairs(t) do
            if value.candidates and value.command then
              value.command = nil
              table.insert(errors, string.format('%s: `candidates` and `command` should not both be set', key))
            elseif value.candidates == nil and value.command == nil then
              value.candidates = {}
              table.insert(errors, string.format('%s: either `candidates` or `command` should be set', key))
            end

            if value.candidates and value.max_files then
              table.insert(errors, string.format('%s: `max_files` has no effect if `candidates` set', key))
            end
          end
        end
        return errors
      end,
    },
    height = { kind = 'number' },
    ignore_case = {
      kind = {
        one_of = {
          {
            kind = 'boolean',
          },
          {
            kind = 'function',
          },
        },
      },
      optional = true,
    },
    mappings = {
      kind = 'table',
      keys = {
        i = {
          kind = 'table',
          values = { kind = 'string' },
        },
        n = {
          kind = 'table',
          values = { kind = 'string' },
        },
      },
    },
    margin = {
      kind = 'number',
      meta = function(context)
        if not is_integer(context.margin) or context.margin < 0 then
          context.margin = 0
          return { '`margin` must be a non-negative integer' }
        end
      end,
    },
    match_listing = {
      kind = 'table',
      keys = {
        border = {
          kind = {
            one_of = {
              'double',
              'none',
              'rounded',
              'shadow',
              'single',
              'solid',
              'winborder',
              { kind = 'list', of = { kind = 'string' } },
            },
          },
        },
        icons = {
          kind = {
            one_of = {
              { kind = 'boolean' },
              { kind = 'function' },
            },
          },
        },
        truncate = {
          kind = {
            one_of = {
              'beginning',
              'middle',
              'end',
              'true',
              'false',
              { kind = 'boolean' },
            },
          },
        },
      },
    },
    never_show_dot_files = { kind = 'boolean' },
    order = { kind = { one_of = { 'forward', 'reverse' } } },
    position = { kind = { one_of = { 'bottom', 'center', 'top' } } },
    prompt = {
      kind = 'table',
      keys = {
        border = {
          kind = {
            one_of = {
              'double',
              'none',
              'rounded',
              'shadow',
              'single',
              'solid',
              'winborder',
              { kind = 'list', of = { kind = 'string' } },
            },
          },
        },
      },
    },
    open = { kind = 'function' },
    root_markers = { kind = 'list', of = { kind = 'string' } },
    scanners = {
      kind = 'table',
      keys = {
        fd = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
          },
          optional = true,
        },
        find = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
          },
          optional = true,
        },
        file = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
          },
          optional = true,
        },
        git = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
            submodules = {
              kind = 'boolean',
              optional = true,
            },
            untracked = {
              kind = 'boolean',
              optional = true,
            },
          },
          meta = function(t)
            if is_table(t) and t.submodules == true and t.untracked == true then
              t.submodules = false
              t.untracked = false
              return { '`submodules` and `untracked` should not both be true' }
            end
          end,
          optional = true,
        },
        rg = {
          kind = 'table',
          keys = {
            max_files = { kind = 'number' },
          },
          optional = true,
        },
      },
    },
    selection_highlight = { kind = 'string' },
    smart_case = {
      kind = {
        one_of = {
          {
            kind = 'boolean',
          },
          {
            kind = 'function',
          },
        },
      },
      optional = true,
    },
    threads = {
      kind = 'number',
      optional = true,
    },
    traverse = { kind = { one_of = { 'file', 'pwd', 'none' } } },
  },
  meta = function(t)
    if t.always_show_dot_files == true and t.never_show_dot_files == true then
      t.always_show_dot_files = false
      t.never_show_dot_files = false
      return { '`always_show_dot_files` and `never_show_dot_files` should not both be true' }
    end
  end,
}

-- Sets `always_show_dot_files = true` and `never_show_dot_files = false` in
-- `options` and returns the mutated table (`options` is a copy, so we're free
-- to mutate it).
local function force_dot_files(options)
  options.always_show_dot_files = true
  options.never_show_dot_files = false
  return options
end

--- @alias CandidatesFunction
--- | fun(directory: string): string[]
--- | # Function that returns a list of candidate strings

local default_options = {
  always_show_dot_files = false,
  finders = {
    -- Returns the list of paths currently loaded into buffers.
    buffer = {
      --- @type CandidatesFunction
      candidates = function(_directory)
        local handles = vim.api.nvim_list_bufs()
        local paths = {}
        for _, handle in ipairs(handles) do
          if vim.api.nvim_buf_is_valid(handle) and vim.api.nvim_get_option_value('buflisted', { buf = handle }) then
            local name = vim.api.nvim_buf_get_name(handle)
            if name ~= '' then
              local relative = vim.fn.fnamemodify(name, ':~:.')
              table.insert(paths, relative)
            end
          end
        end
        return paths
      end,
      options = force_dot_files,
    },
    fd = {
      command = function(directory, options)
        pushd(directory)
        local command = 'fd --hidden --print0 --type file --search-path . 2> /dev/null'
        local drop = 2 -- drop './'
        return command, drop
      end,
      fallback = true,
      max_files = function(options)
        return options.scanners.fd.max_files
      end,
      on_close = popd,
      on_directory = on_directory,
      open = on_open,
    },
    find = {
      command = function(directory, options)
        pushd(directory)
        local command = 'find -L . -type f -print0 2> /dev/null'
        local drop = 2 -- drop './'
        return command, drop
      end,
      fallback = true,
      max_files = function(options)
        return options.scanners.find.max_files
      end,
      on_close = popd,
      on_directory = on_directory,
      open = on_open,
    },
    git = {
      command = function(directory, options)
        if directory ~= '' then
          directory = vim.fn.shellescape(directory)
        end
        local command = 'git ls-files --exclude-standard --cached -z'
        if directory ~= '' then
          command = 'git -C ' .. directory .. ' ls-files --exclude-standard --cached -z'
        end
        if options.scanners.git.submodules then
          command = command .. ' --recurse-submodules'
        elseif options.scanners.git.untracked then
          command = command .. ' --others'
        end
        command = command .. ' 2> /dev/null'
        local drop = 0
        return command, drop
      end,
      fallback = true,
      max_files = function(options)
        return options.scanners.git.max_files
      end,
      on_directory = on_directory,
      open = on_open,
    },
    help = {
      candidates = function(_directory)
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
        return helptags
      end,
      kind = 'virtual',
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
      options = force_dot_files,
    },
    line = {
      candidates = function(_directory)
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
      kind = 'virtual',
      open = function(item)
        -- Extract line number from (eg) "some line contents:100".
        local suffix = string.find(item, '%d+$')
        local index = tonumber(item:sub(suffix))
        vim.api.nvim_win_set_cursor(0, { index, 0 })
      end,
      options = force_dot_files,
    },
    rg = {
      command = function(directory, options)
        pushd(directory)
        local command = 'rg --files --null 2> /dev/null'
        local drop = 0
        return command, drop
      end,
      fallback = true,
      max_files = function(options)
        return options.scanners.rg.max_files
      end,
      on_close = popd,
      on_directory = on_directory,
      open = on_open,
    },
  },
  height = 15,

  -- If nil, will infer from Neovim's `'ignorecase'`.
  ignore_case = function()
    return vim.o.ignorecase
  end,

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
  match_listing = {
    border = { '', '', '', '│', '┘', '─', '└', '│' }, -- 'double', 'none', 'rounded', 'shadow', 'single', 'solid', 'winborder', or a list of strings.
    icons = true,
    truncate = 'middle',
  },
  never_show_dot_files = false,
  order = 'forward', -- 'forward', 'reverse'.
  position = 'center', -- 'bottom', 'center', 'top'.
  prompt = {
    border = { '┌', '─', '┐', '│', '┤', '─', '├', '│' }, -- 'double', 'none', 'rounded', 'shadow', 'single', 'solid', 'winborder', or a list of strings.
  },
  open = smart_open,
  root_markers = { '.git', '.hg', '.svn', '.bzr', '_darcs' },
  scanners = {
    fd = {
      max_files = 0,
    },
    file = {
      max_files = 0,
    },
    find = {
      max_files = 0,
    },
    git = {
      max_files = 0,
      submodules = true,
      untracked = false,
    },
    rg = {
      max_files = 0,
    },
  },
  selection_highlight = 'PmenuSel',

  -- If nil, will infer from Neovim's `'smartcase'`.
  smart_case = function()
    return vim.o.smartcase
  end,

  threads = nil, -- Let heuristic apply.
  traverse = 'none', -- 'file', 'pwd' or 'none'.
}

local _options = nil

-- Have to add some of these explicitly otherwise the ones with `nil` defaults
-- (eg. `threads`) won't come through.
local allowed_options = concat(keys(default_options), {
  'threads',
})

local get_directory = function()
  local options = commandt.options()
  if options.traverse == 'file' then
    local file = vim.fn.expand('%:p:h') -- If no current file, returns current dir.
    return require('wincent.commandt.private.find_root')(file, options.root_markers)
  elseif options.traverse == 'pwd' then
    return require('wincent.commandt.private.find_root')(vim.fn.getcwd(), options.root_markers)
  else
    return vim.fn.getcwd()
  end
end

commandt._directory = get_directory

commandt.default_options = function(options)
  local result = copy(default_options)

  -- Swap border definitions if `position = 'bottom'` is set.
  if type(options) == 'table' and options.position == 'bottom' then
    result.match_listing.border = default_options.prompt.border
    result.prompt.border = default_options.match_listing.border
  end

  return result
end

commandt.file_finder = function(directory)
  directory = vim.trim(directory)
  if directory == '' then
    directory = get_directory()
  end
  pushd(directory)
  local ui = require('wincent.commandt.private.ui')
  local options = commandt.options()
  local finder = require('wincent.commandt.private.finders.file')('.', options)
  ui.show(
    finder,
    merge(options, {
      name = 'file',
      on_open = function(result)
        return relativize(directory, result)
      end,
      on_close = popd,
    })
  )
end

local report_errors = function(errors, heading)
  if #errors > 0 then
    table.insert(errors, 1, heading .. ':')
    for i, message in ipairs(errors) do
      local indent = i == 1 and '' or '  '
      errors[i] = { indent .. message .. '\n', 'WarningMsg' }
    end
    vim.api.nvim_echo(errors, true, {})
  end
end

-- Returns a sanitized copy of `options` (with bad values fixed, if possible),
-- and a table of errors. `base`, if provided, is an options object to extend.
local sanitize_options = function(options, base)
  local errors = {}
  options = copy(options or {})
  if not is_table(options) then
    table.insert(errors, 'expected a table of options but received ' .. type(options))
    options = {}
  end
  if base ~= nil then
    options = merge(base, options)
  end

  local validate = require('wincent.commandt.private.validate')
  errors = merge(errors, validate('', nil, options, options_spec, commandt.default_options(options)))
  return options, errors
end

commandt.finder = function(name, directory)
  local options = commandt.options()
  local config = options.finders[name]
  if config == nil then
    error('commandt.finder(): no finder registered with name ' .. tostring(name))
  end
  local kind = config.kind
  if config.options then
    -- Optionally transform options.
    local sanitized_options, errors = sanitize_options(config.options(options))
    report_errors(errors, 'commandt.finder()')
    options = sanitized_options
  end
  if directory ~= nil then
    directory = vim.trim(directory)
  end
  if config.on_directory then
    directory = config.on_directory(directory)
  end
  local finder = nil
  options.open = function(item, kind)
    if config.open then
      config.open(item, kind, directory, commandt.open)
    else
      commandt.open(item, kind)
    end
  end
  if config.candidates then
    finder = require('wincent.commandt.private.finders.list')(directory, config.candidates, options)
  else
    finder = require('wincent.commandt.private.finders.command')(directory, config.command, options, name)
  end
  if config.fallback then
    finder.fallback = require('wincent.commandt.private.finders.fallback')(finder, directory, options)
  end
  local ui = require('wincent.commandt.private.ui')

  -- TODO: fix type smell here. we're merging "kind", a property that exists
  -- inside matcher configs, into the top level, along with "name".
  ui.show(
    finder,
    merge(options, {
      name = name,
      kind = kind,
      on_close = config.on_close,
    })
  )
end

-- Expose these functions publicly for use by custom finders.
commandt.popd = popd
commandt.pushd = pushd
commandt.on_directory = on_directory
-- TODO: maybe rename this
commandt.on_open = on_open
-- TODO: probably rename this to smart_open
commandt.open = smart_open

commandt.options = function()
  return copy(_options or commandt.default_options())
end

commandt.setup = function(options)
  local sanitized_options, errors = sanitize_options(options, _options or commandt.default_options(options))
  _options = sanitized_options

  if vim.g.CommandTPreferredImplementation == 'ruby' then
    table.insert(errors, 1, '`commandt.setup()` was called, but `g:CommandTPreferredImplementation` is set to "ruby"')
  else
    vim.g.CommandTPreferredImplementation = 'lua'
  end

  if
    not pcall(function()
      local lib = require('wincent.commandt.private.lib') -- We can require it.
      lib.epoch() -- We can use it.
    end)
  then
    table.insert(errors, 'unable to load and use C library - run `:checkhealth wincent.commandt`')
  end

  report_errors(errors, 'commandt.setup()')
end

commandt.watchman_finder = function(directory)
  directory = vim.trim(directory)
  if directory == '' then
    directory = get_directory()
  end
  local ui = require('wincent.commandt.private.ui')
  local options = commandt.options()
  local finder = require('wincent.commandt.private.finders.watchman')(directory, options)
  ui.show(
    finder,
    merge(options, {
      name = 'watchman',
      on_open = function(result)
        return relativize(directory, result)
      end,
    })
  )
end

return commandt
