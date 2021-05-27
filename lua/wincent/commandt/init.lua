-- Copyright 2010-present Greg Hurrell. All rights reserved.
-- Licensed under the terms of the BSD 2-clause license.

local ffi = require('ffi')

local commandt = {}

local chooser_buffer = nil
local chooser_selected_index = nil
local chooser_window = nil

local library = nil

-- require('wincent.commandt.finder')
library = {
  commandt_example_func_that_returns_int = function()
    library = library.load()

    return library.commandt_example_func_that_returns_int()
  end,

  commandt_example_func_that_returns_str = function()
    library = library.load()

    return library.commandt_example_func_that_returns_str()
  end,

  commandt_example_func_that_takes_a_table_of_strings = function()
  end,

  load = function ()
    local dirname = debug.getinfo(1).source:match('@?(.*/)')
    local extension = '.so' -- TODO: handle Windows .dll extension
    local loaded = ffi.load(dirname .. 'commandt' .. extension)

    ffi.cdef[[
      typedef struct {
          size_t count;
          const char **matches;
      } matches_t;

      int commandt_example_func_that_returns_int();
      const char *commandt_example_func_that_returns_str();


      void commandt_example_func_that_takes_a_table_of_strings(
        const char **candidates
      );

      const int *commandt_example_func_that_returns_table_of_ints();

      matches_t commandt_sorted_matches_for(const char *needle);

    ]]
    -- TODO: avoid this; prefer to call destructor instead with ffi.gc and let
    -- C-side code do the freeing...
    -- void free(void *ptr);

    return loaded
  end,
}

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
  print(library.commandt_example_func_that_returns_int())

  print(ffi.string(library.commandt_example_func_that_returns_str()))


  -- 3 items + 1 NUL terminator
  library.commandt_example_func_that_takes_a_table_of_strings(ffi.new("const char *[4]", {
    "one",
    "two",
    "three",
  }))

  local indices = library.commandt_example_func_that_returns_table_of_ints()

  -- TODO copy this kind somewhere useful (ie. a cheatsheet)
  -- we can look up the size of the pointer to the array, but not
  -- the length of the array itself; it is terminated with a -1.
  -- print(ffi.sizeof(indices)) -- 8
  -- print(tostring(ffi.typeof(indices))) -- ctype<const int *>

  local i = 0
  while true do
    local index = tonumber(indices[i])
    if index == -1 then
      break
    end
    print(index)
    i = i + 1
  end

  local sorted = --ffi.gc(
    library.commandt_sorted_matches_for('some query')--,
    -- ffi.C.free
  --)
  -- (Note: don't free here, better to tell matcher/scanner to destruct and do its own free-ing)

  -- tonumber() needed here because ULL (boxed)
  for i = 1, tonumber(sorted.count) do
    print(ffi.string(sorted.matches[i - 1]))
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
          print('opn')
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
