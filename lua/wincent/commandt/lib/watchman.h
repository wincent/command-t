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

// TODO: Either use uint8_t for both requests and responses, or char for both.
/**
 * @internal
 */
typedef struct {
    size_t capacity;
    char *payload;
    char *ptr;
    char *end;
} watchman_response_t;

typedef struct {
    str_t *files;
    unsigned count;
    watchman_response_t *__response; /** @internal */
} watchman_query_result_t;

typedef struct {
    const char *watch;
    const char *relative_path; /** May be NULL. */
} watchman_watch_project_result_t;

int commandt_watchman_connect(const char *socket_path);

int commandt_watchman_disconnect(int socket);

/**
 * Equivalent to:
 *
 *      watchman -j <<JSON
 *          [
 *              "query",
 *              "/path/to/root", {
 *                  "expression": ["type", "f"],
 *                  "fields": ["name"],
 *                  "relative_root": "relative/path"
 *              }
 *          ]
 *      JSON
 *
 * As a performance optimization, the slab of memory allocated to hold
 * the response from the Watchman server is preserved and the returned
 * `watchman_query_result_t` struct contains `str_t` structs that
 * reference the underlying memory in the slab, rather than allocating new
 * copies.  As such, if you need to access those strings after a call to
 * `commandt_watchman_query_result_free()`, you must make a copy.
 */
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
