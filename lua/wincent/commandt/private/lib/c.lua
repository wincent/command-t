-- SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

-- We lazy-load dynamic library (C) code on first access.
local c = {}

setmetatable(c, {
  __index = function(_, key)
    ffi.cdef([[
      // Types.

      typedef struct {
          const char *contents;
          size_t length;
          ssize_t capacity;
      } str_t;

      typedef struct {
          str_t *candidate;
          long bitmask;
          float score;
      } haystack_t;

      typedef struct {
          unsigned count;
          str_t *candidates;
          ssize_t candidates_size;
          char *buffer;
          ssize_t buffer_size;
      } scanner_t;

      typedef struct {
          scanner_t *scanner;
          haystack_t *haystacks;
          bool always_show_dot_files;
          bool ignore_case;
          bool ignore_spaces;
          bool never_show_dot_files;
          bool smart_case;
          unsigned limit;
          unsigned threads;
          const char *needle;
          size_t needle_length;
          long needle_bitmask;
          const char *last_needle;
          size_t last_needle_length;
      } matcher_t;

      typedef struct {
          str_t **matches;
          unsigned match_count;
          unsigned candidate_count;
      } result_t;

      typedef struct {
          size_t capacity;
          char *payload;
          char *ptr;
          char *end;
      } watchman_response_t;

      typedef struct {
          unsigned count;
          str_t *files;
          const char *error;
          size_t files_size;
          watchman_response_t *response;
      } watchman_query_t;

      typedef struct {
          const char *watch;
          const char *relative_path;
          const char *error;
      } watchman_watch_project_t;

      typedef struct {
        uint32_t seconds;
        uint32_t microseconds;
      } benchmark_t;

      // Matcher functions.

      matcher_t *commandt_matcher_new(
          scanner_t *scanner,
          bool always_show_dot_files,
          bool ignore_case,
          bool ignore_spaces,
          unsigned limit,
          bool never_show_dot_files,
          bool smart_case,
          uint64_t threads
      );
      void commandt_matcher_free(matcher_t *matcher);
      result_t *commandt_matcher_run(matcher_t *matcher, const char *needle);
      void commandt_result_free(result_t *result);

      // Scanner functions.

      scanner_t *commandt_file_scanner(const char *directory, unsigned max_files);
      scanner_t *commandt_scanner_new_command(const char *command, unsigned drop, unsigned max_files);
      scanner_t *commandt_scanner_new_copy(const char **candidates, unsigned count);
      scanner_t *commandt_scanner_new_str(str_t *candidates, unsigned count);
      void commandt_scanner_free(scanner_t *scanner);
      void commandt_print_scanner(scanner_t *scanner);

      // Watchman functions.

      int commandt_watchman_connect(const char *socket_path);
      int commandt_watchman_disconnect(int socket);
      watchman_query_t *commandt_watchman_query(
          const char *root,
          const char *relative_root,
          int socket
      );
      void commandt_watchman_query_free(watchman_query_t *result);
      watchman_watch_project_t *commandt_watchman_watch_project(
          const char *root,
          int socket
      );
      void commandt_watchman_watch_project_free(
          watchman_watch_project_t *result
      );

      // Benchmarking.

      benchmark_t commandt_epoch();

      // Utilities.

      unsigned commandt_processors();

      // Standard library.
      void free(void *ptr);
    ]])

    local dirname = debug.getinfo(1).source:match('@?(.*/)')
    local extension = (function()
      -- Possible values listed here: http://luajit.org/ext_jit.html#jit_os
      if ffi.os == 'Windows' then
        return '.dll'
      end
      return '.so'
    end)()
    c = ffi.load(dirname .. '../../lib/commandt' .. extension)
    return c[key]
  end,
})

return c
