/**
 * SPDX-FileCopyrightText: Copyright 2014-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

/**
 * @file
 *
 * Methods for working with the Watchman binary protocol
 *
 * @see https://github.com/facebook/watchman/blob/master/website/_docs/BSER.markdown
 */

#ifndef WATCHMAN_H
#define WATCHMAN_H

#include "str.h" /* for str_t */

typedef struct {
    str_t **files;
    unsigned count;
} watchman_query_result_t;

typedef struct {
    const char *watch;
    const char *relative_path; /** May be NULL. */
} watchman_watch_project_result_t;

//
// query = ['watch-project', '/root/path/string']
// result = {...}
// root = result['watch']
// relative_path = result['relative_path'] (if it has that key)
// other fields:
//   version: "..."
//   watcher: "..."
//   error: "..." if there was one (Ruby implementation raises)
//
// query = ['query', root, {
//   'expression' => ['type', 'f'],
//   'fields' => ['name'],
//   'relative_root' => relative_path, (if we got that key)
// }]
// result = {...}
// paths = result['files']
// fields that may be present but which aren't that interesting to us:
//   is_fresh_instance: true
//   version: "..."
//   warning: "..."
//   clock: "..."
//   debug: {cookie_files: ["..."]}
//   error: "..." if there was one (Ruby implementation raises)
//
// Note also that we don't need to return Lua strings. We can return pointer to
// array of str_t*

int commandt_watchman_connect(const char *socket_path);

int commandt_watchman_disconnect(int socket);

watchman_query_result_t *commandt_watchman_query(
    const char *root,
    const char *relative_root,
    int socket
);

void commandt_watchman_query_result_free(watchman_query_result_t *result);

/**
 * Equivalent to `watchman watch-project /path/to/root`.
 */
watchman_watch_project_result_t *commandt_watchman_watch_project(
    const char *root,
    int socket
);

void commandt_watchman_watch_project_result_free(
    watchman_watch_project_result_t *result
);

#endif
