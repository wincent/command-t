/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef MATCHER_H
#define MATCHER_H

#include <stdbool.h> /* for bool */

#include "scanner.h" /* for scanner_t */
#include "str.h" /* for str_t */

// TODO flesh this out; basically make it a container for instance variables
typedef struct {
    scanner_t *scanner;

    bool always_show_dot_files;
    bool case_sensitive;
    bool ignore_spaces;
    bool never_show_dot_files;
    bool recurse;
    // bool sort;

    /**
     * Limit the number of returned results (0 implies no limit).
     */
    unsigned limit;
    int threads;

    const char *last_needle;
    unsigned long last_needle_length;
    // etc
} matcher_t;

// TODO: may later want to return highlight positions as well
typedef struct {
    str_t **matches;
    unsigned count;
} result_t;

matcher_t *commandt_matcher_new(
    scanner_t *scanner,
    bool always_show_dot_files,
    bool never_show_dot_files
);

// TODO: use this
void commandt_matcher_free(matcher_t *matcher);

/**
 * It is the responsibility of the caller to free the results struct by calling
 * `commandt_result_free()`.
 */
result_t *commandt_matcher_run(matcher_t *matcher, const char *needle);

void commandt_result_free(result_t *results);

#endif
