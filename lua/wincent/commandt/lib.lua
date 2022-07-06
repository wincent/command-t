-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local lib = {}

-- Lazy-load dynamic (C) library code on first access.
local c = {}

setmetatable(c, {
  __index = function(table, key)
    ffi.cdef[[
      typedef struct {
          const char *contents;
          size_t length;
          size_t capacity;
      } str_t;

      typedef struct {
          str_t *candidate;
          long length;
          long index;
          long bitmask;
          float score;
      } haystack_t;

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
          str_t **matches;
          unsigned count;
      } result_t;

      float commandt_calculate_match(
          haystack_t *haystack,
          const char *needle,
          bool case_sensitive,
          bool always_show_dot_files,
          bool never_show_dot_files,
          bool recurse,
          long needle_bitmask
      );

      // Matcher methods.

      matcher_t *commandt_matcher_new(
          scanner_t *scanner,
          bool always_show_dot_files,
          bool never_show_dot_files
      );
      void commandt_matcher_free(matcher_t *matcher);
      result_t *commandt_matcher_run(matcher_t *matcher, const char *needle);

      void commandt_result_free(result_t *result);

      // Not sure if going to need this...
      //matches_t commandt_sorted_matches_for(const char *needle);

      // Scanner methods.

      scanner_t *scanner_new_copy(const char **candidates, size_t count);
      void scanner_free(scanner_t *scanner);
      void commandt_print_scanner(scanner_t *scanner);
    ]]

    local dirname = debug.getinfo(1).source:match('@?(.*/)')
    local extension = (function()
      -- Possible values listed here: http://luajit.org/ext_jit.html#jit_os
      if ffi.os == 'Windows' then
        return '.dll'
      end
      return '.so'
    end)()
    c = ffi.load(dirname .. 'commandt' .. extension)
    return c[key]
  end
})

lib.commandt_matcher_new = function(
  scanner,
  always_show_dot_files,
  never_show_dot_files
)
  return c.commandt_matcher_new(scanner, always_show_dot_files, never_show_dot_files)
end

lib.commandt_matcher_run = function(matcher, needle)
  print('hi')
  print('there')
  print('friend')
  return c.commandt_matcher_run(matcher, needle)
end

lib.demo = function()
  error('delete me')
end

lib.print_scanner = function(scanner)
  c.commandt_print_scanner(scanner)
end

lib.scanner_new_copy = function(candidates)
  -- TODO: benchmark this approach (passing an array of strings and then calling
  -- `strlen()` on the C-side) vs constructing and passing structs from the Lua
  -- side:
  --
  --     ffi.new('str_t *[4]', {
  --       ffi.new('str_t', {'stuff', 5, 5}),
  --       ffi.new('str_t', {'more', 4, 4}),
  --       ffi.new('str_t', {'and', 3, 3}),
  --       ffi.new('str_t', {'rest', 4, 4}),
  --     }), 4)
  --
  local count = #candidates
  scanner = c.scanner_new_copy(
    ffi.new('const char *[' .. count .. ']', candidates),
    count
  )
  ffi.gc(scanner, c.scanner_free)
  return scanner
end

return lib
