-- SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
-- SPDX-License-Identifier: BSD-2-Clause

local ffi = require('ffi')

local merge = require('wincent.commandt.private.merge')

local lib = {}

-- Lazy-load dynamic (C) library code on first access.
local c = {}

setmetatable(c, {
  __index = function(table, key)
    ffi.cdef([[
      // Types.

      typedef struct {
          const char *contents;
          size_t length;
          size_t capacity;
      } str_t;

      typedef struct {
          str_t *candidate;
          long bitmask;
          float score;
      } haystack_t;

      typedef struct {
          unsigned count;
          str_t *candidates;
          size_t candidates_size;
          char *buffer;
          size_t buffer_size;
          unsigned clock;
      } scanner_t;

      typedef struct {
          scanner_t *scanner;
          haystack_t *haystacks;
          bool always_show_dot_files;
          bool case_sensitive;
          bool ignore_spaces;
          bool never_show_dot_files;
          bool recurse;
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
          unsigned count;
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
          size_t files_size;
          watchman_response_t *response;
      } watchman_query_result_t;

      typedef struct {
          const char *watch;
          const char *relative_path;
      } watchman_watch_project_result_t;

      typedef struct {
        uint32_t seconds;
        uint32_t microseconds;
      } benchmark_t;

      // Matcher methods.

      matcher_t *commandt_matcher_new(
          scanner_t *scanner,
          bool always_show_dot_files,
          bool case_sensitive,
          bool ignore_spaces,
          unsigned limit,
          bool never_show_dot_files,
          bool recurse,
          unsigned threads
      );
      void commandt_matcher_free(matcher_t *matcher);
      result_t *commandt_matcher_run(matcher_t *matcher, const char *needle);
      void commandt_result_free(result_t *result);

      // Scanner methods.

      scanner_t *scanner_new_command(const char *command);
      scanner_t *scanner_new_copy(const char **candidates, unsigned count);
      scanner_t *scanner_new_str(str_t *candidates, unsigned count);
      void scanner_free(scanner_t *scanner);
      void commandt_print_scanner(scanner_t *scanner);

      // Watchman methods.

      int commandt_watchman_connect(const char *socket_path);
      int commandt_watchman_disconnect(int socket);
      watchman_query_result_t *commandt_watchman_query(
          const char *root,
          const char *relative_root,
          int socket
      );
      void commandt_watchman_query_result_free(watchman_query_result_t *result);
      watchman_watch_project_result_t *commandt_watchman_watch_project(
          const char *root,
          int socket
      );
      void commandt_watchman_watch_project_result_free(
          watchman_watch_project_result_t *result
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
    c = ffi.load(dirname .. '../lib/commandt' .. extension)
    return c[key]
  end,
})

lib.commandt_epoch = function()
  local result = c.commandt_epoch()

  return result['seconds'], result['microseconds']
end

lib.commandt_matcher_new = function(scanner, options)
  options = merge({
    always_show_dot_files = false,
    case_sensitive = false,
    ignore_spaces = true,
    limit = 15,
    never_show_dot_files = false,
    recurse = true,
    threads = lib.commandt_processors(),
  }, options)
  if options.limit < 1 then
    error('limit must be > 0')
  end
  local matcher = c.commandt_matcher_new(
    scanner,
    options.always_show_dot_files,
    options.case_sensitive,
    options.ignore_spaces,
    options.limit,
    options.never_show_dot_files,
    options.recurse,
    options.threads
  )
  ffi.gc(matcher, c.commandt_matcher_free)
  return matcher
end

lib.commandt_matcher_run = function(matcher, needle)
  return c.commandt_matcher_run(matcher, needle)
end

lib.commandt_processors = function()
  return c.commandt_processors()
end

-- TODO: order this file
lib.print_scanner = function(scanner)
  c.commandt_print_scanner(scanner)
end

lib.scanner_new_command = function(command)
  local scanner = c.scanner_new_command(command)
  -- ffi.gc(scanner, c.scanner_free)
  return scanner
end

lib.scanner_new_copy = function(candidates)
  local count = #candidates
  local scanner = c.scanner_new_copy(ffi.new('const char *[' .. count .. ']', candidates), count)
  ffi.gc(scanner, c.scanner_free)
  return scanner
end

lib.scanner_new_str = function(candidates, count)
  local scanner = c.scanner_new_str(candidates, count)
  ffi.gc(scanner, c.scanner_free)
  return scanner
end

lib.commandt_watchman_connect = function(name)
  -- TODO: validate name is a string/path
  local socket = c.commandt_watchman_connect(name)
  if socket == -1 then
    error('commandt_watchman_connect(): failed')
  end
  return socket
end

lib.commandt_watchman_disconnect = function(socket)
  -- TODO: validate socket is a number
  local errno = c.commandt_watchman_disconnect(socket)
  if errno ~= 0 then
    error('commandt_watchman_disconnect(): failed with errno ' .. errno)
  end
end

lib.commandt_watchman_query = function(root, relative_root, socket)
  local result = c.commandt_watchman_query(root, relative_root, socket)
  ffi.gc(result, c.commandt_watchman_query_result_free)
  return result
end

lib.commandt_watchman_watch_project = function(root, socket)
  local result = c.commandt_watchman_watch_project(root, socket)
  local project = {
    watch = ffi.string(result['watch']),
  }
  if result['relative_path'] ~= nil then
    project['relative_path'] = ffi.string(result['relative_path'])
  end
  c.commandt_watchman_watch_project_result_free(result)
  return project
end

return lib
