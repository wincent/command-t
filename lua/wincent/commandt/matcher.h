/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef MATCHER_H
#define MATCHER_H

#include <stdbool.h> /* for bool */

#include "commandt.h" /* for matcher_t */
#include "str.h" /* for str_t */

// TODO: may later want to return highlight positions as well
typedef struct {
    str_t **matches;
    unsigned count;
} result_t;

/**
 * Returns a new matcher.
 *
 * The caller should dispose of the returned matcher with a call to
 * `commandt_matcher_free()`.
 */
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

/**
 * Frees a previously allocated matcher. Note that the associated scanner should
 * be freed separately.
 */
void commandt_matcher_free(matcher_t *matcher);

/**
 * It is the responsibility of the caller to free the results struct by calling
 * `commandt_result_free()`.
 */
result_t *commandt_matcher_run(matcher_t *matcher, const char *needle);

void commandt_result_free(result_t *results);

// TODO: figure out whether I can safely drop the `commandt_` prefixes to these
// functions... (or whether we should be _adding_ more prefixes to other places
// that don't currently have them).

#endif
