-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local lib = {}

local c = {}

-- Lazy-load dynamic library code on first access.
setmetatable(c, {
  __index = function(table, key)
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
      scanner_t *commandt_another_demo(const char **candidates, size_t count);

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

      void scanner_free(scanner_t *scanner);
    ]]

    local dirname = debug.getinfo(1).source:match('@?(.*/)')
    local extension = '.so' -- TODO: handle Windows .dll extension
    c = ffi.load(dirname .. 'commandt' .. extension)
    return c[key]
  end
})

lib.demo = function()
  local result = c.commandt_temporary_demo_function(
    ffi.new('str_t *[4]', {
      ffi.new('str_t', {'stuff', 5, 5}),
      ffi.new('str_t', {'more', 4, 4}),
      ffi.new('str_t', {'and', 3, 3}),
      ffi.new('str_t', {'rest', 4, 4}),
    }), 4)
  print(vim.inspect(result))
end

-- goal here is just to show that I can allocate stuff in C land and return a
-- "handle" that can be used latter to dispose of resources.
lib.demo2 = function()
  -- It's not quite magic enough to do this...
  -- bad argument #1 to 'commandt_another_demo' (cannot convert 'table' to 'const char **')
  -- local result = c.commandt_another_demo({"does", "this", "work?"}, 3)
  -- But it can do this:
  local result = c.commandt_another_demo(
    ffi.new('const char *[3]', {"does", "this", "work?"}),
    3
  )
  print(vim.inspect(result))
  ffi.gc(result, c.scanner_free)
end

return lib
