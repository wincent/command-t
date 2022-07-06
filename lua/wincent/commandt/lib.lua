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

      scanner_t *scanner_new_copy(const char **candidates, size_t count);
      void scanner_free(scanner_t *scanner);

      void commandt_print_scanner(scanner_t *scanner);
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

lib.print_scanner = function(scanner)
  c.commandt_print_scanner(scanner)
end

lib.scanner_new_copy = function(candidates)
  local count = #candidates
  scanner = c.scanner_new_copy(
    ffi.new('const char *[' .. count .. ']', candidates),
    count
  )
  ffi.gc(scanner, c.scanner_free)
  return scanner
end

return lib
