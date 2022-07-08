/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef COMMANDT_H
#define COMMANDT_H

#include <stdbool.h> /* for bool */
#include <stddef.h> /* for size_t */

#include "str.h" /* for str_t */

/**
 *  Represents a single "haystack" (ie. a string to be searched for the needle).
 */
typedef struct {
    str_t *candidate;
    long bitmask;
    float score;
} haystack_t;

typedef struct {
    // TODO: const
    str_t **candidates;

    /**
     * Number of candidates currently stored in the scanner.
     */
    unsigned count;

    /**
     * Available capacity in the scanner.
     */
    unsigned capacity;

    /**
     * Counter that increments any time the candidates change.
     */
    unsigned clock; // TODO: figure out whether I need this
} scanner_t;

// TODO flesh this out; basically make it a container for instance variables
typedef struct {
    /**
     * Note the matcher doesn't take ownership of the `scanner` as these can be
     * expensive to copy or recreate.
     */
    scanner_t *scanner;
    haystack_t *haystacks;

    bool always_show_dot_files;
    bool case_sensitive;
    bool ignore_spaces;
    bool never_show_dot_files;
    bool recurse;
    // bool sort;

    /**
     * Limit the number of returned results. Must be non-zero.
     */
    unsigned limit;
    unsigned threads;

    /**
     * Note that the matcher doesn't take ownership of the `needle` (ie. it
     * doesn't make a copy of it) because it only needs it to stick around long
     * enough to calculate scores with it. These fields are merely here as a
     * convenience for temporarily threading state through to `commandt_score()`
     * and friends.
     */
    const char *needle;
    size_t needle_length;
    long needle_bitmask;

    const char *last_needle;
    size_t last_needle_length;
} matcher_t;

#endif
