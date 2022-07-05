-- SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell. All rights reserved.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local commandt = {}

local chooser_buffer = nil
local chooser_selected_index = nil
local chooser_window = nil

-- Lazy loaded.
local library = nil

-- require('wincent.commandt.finder') -- TODO: decide whether we need this, or
-- only scanners
local scanner = require('wincent.commandt.scanner')

-- print('scanner ' .. vim.inspect(scanner.buffer.get()))

local load = function ()
  local dirname = debug.getinfo(1).source:match('@?(.*/)')
  local extension = '.so' -- TODO: handle Windows .dll extension
  library = ffi.load(dirname .. 'commandt' .. extension)

  ffi.cdef[[
    typedef struct {
        const char *candidate;
        long length;
        long index;
        long bitmask;
        float score;
    } haystack_t;

    typedef struct {
        const char *contents;
        size_t length;
        size_t capacity;
    } str_t;

    typedef struct {
        str_t **candidates;
        size_t count;
        size_t capacity;
        unsigned clock;
    } scanner_t;

    typedef struct {
        scanner_t *scanner;
        bool always_show_dot_files;
        bool case_sensitive;
        bool ignore_spaces;
        bool never_show_dot_files;
        bool recurse;
        bool sort;
        unsigned limit;
        int threads;
        const char *last_needle;
        unsigned long last_needle_length;
    } matcher_t;

    //typedef struct {
    //    size_t count;
    //    const char **matches;
    //} matches_t;

    typedef struct {
        long count;
        long *indices;
    } result_t;

    result_t *commandt_matcher_run(matcher_t *matcher, const char *needle);

    //result_t *commandt_temporary_demo_function();
    int commandt_temporary_demo_function(str_t **candidates, size_t count);

    float commandt_calculate_match(
        haystack_t *haystack,
        const char *needle,
        bool case_sensitive,
        bool always_show_dot_files,
        bool never_show_dot_files,
        bool recurse,
        long needle_bitmask
    );

    void commandt_result_free(result_t *result);

    //matches_t commandt_sorted_matches_for(const char *needle);
  ]]
  -- TODO: avoid this; prefer to call destructor instead with ffi.gc and let
  -- C-side code do the freeing...
  -- void free(void *ptr);

  return library
end

-- library = {
  -- commandt_example_func_that_returns_int = function()
  --   if not loaded then
  --     library = library.load()
  --   end
  --
  --   return library.commandt_example_func_that_returns_int()
  -- end,
  --
  -- commandt_example_func_that_returns_str = function()
  --   if not loaded then
  --     library = library.load()
  --   end
  --
  --   return library.commandt_example_func_that_returns_str()
  -- end,
-- }

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

  -- print(library.commandt_example_func_that_returns_int())
  --
  -- print(ffi.string(library.commandt_example_func_that_returns_str()))
  --
  -- local t = {
  --     "one",
  --     "two",
  --     "three",
  --   }
  --   local ffi_t = ffi.new("const char *[4]", t);
  -- local flag = library.commandt_example_func_that_takes_a_table_of_strings(
  --   ffi.new("int", 3),
  --   -- 3 items + 1 NUL terminator
  --   ffi_t)
  --
  -- print('flag '..tonumber(flag))
  --
  -- local flag2 = library.commandt_example_func_that_takes_a_table_of_strings(
  --   ffi.new("int", 3),
  --   -- 3 items + 1 NUL terminator
  --   ffi_t -- this produces the same pointer
  --   -- ffi.new("const char *[4]", t) -- this is a diff value, producing a diff
  --   -- pointer
  --   )
  --
  -- print('flag2 '..tonumber(flag2))
  --
  -- -- and nil
  -- local flag3 = library.commandt_example_func_that_takes_a_table_of_strings(
  -- ffi.new("int", 0),
  -- ffi.new("const char *[1]", nil) -- does not wind up as NULL over there
  -- )
  -- print('flag3 '..tonumber(flag3))
  --
  -- local indices = library.commandt_example_func_that_returns_table_of_ints()
  --
  -- -- TODO copy this kind somewhere useful (ie. a cheatsheet)
  -- -- we can look up the size of the pointer to the array, but not
  -- -- the length of the array itself; it is terminated with a -1.
  -- -- print(ffi.sizeof(indices)) -- 8
  -- -- print(tostring(ffi.typeof(indices))) -- ctype<const int *>
  --
  -- local i = 0
  -- while true do
  --   local index = tonumber(indices[i])
  --   if index == -1 then
  --     break
  --   end
  --   print(index)
  --   i = i + 1
  -- end
  --
  -- local sorted = --ffi.gc(
  --   library.commandt_sorted_matches_for('some query')--,
  --   -- ffi.C.free
  -- --)
  -- -- (Note: don't free here, better to tell matcher/scanner to destruct and do its own free-ing)
  --
  -- -- tonumber() needed here because ULL (boxed)
  -- for i = 1, tonumber(sorted.count) do
  --   print(ffi.string(sorted.matches[i - 1]))
  -- end
end

-- test this out with:
-- :lua print(vim.inspect(require('wincent.commandt').calculate_match('haystack', 'stack')))
-- TODO: decide whether to leave this around or not (probably will keep it as
-- it may be useful)
commandt.calculate_match = function(
  haystack,
  needle,
  case_sensitive,
  always_show_dot_files,
  never_show_dot_files,
  recurse,
  needle_bitmask
)
  local l = load()

  local result = l.commandt_calculate_match(
    ffi.new('haystack_t', {haystack, string.len(haystack), 0, -1, 0}),
    needle,
    case_sensitive or true,
    always_show_dot_files or false,
    never_show_dot_files or false,
    recurse or true,
    needle_bitmask or 0
  )

  -- TODO: make this callable more than once
  -- (ie. on first time we accept a string, on second etc times we need called
  -- to do ffi.new thing)
  commandt.calculate_match = l.commandt_calculate_match

  return result
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

commandt.demo = function()
  local l = load()
  local result = l.commandt_temporary_demo_function(
    ffi.new('str_t *[4]', {
      ffi.new('str_t', {'stuff', 5, 5}),
      ffi.new('str_t', {'more', 4, 4}),
      ffi.new('str_t', {'and', 3, 3}),
      ffi.new('str_t', {'rest', 4, 4}),
    }), 4)
  print(vim.inspect(result))
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
