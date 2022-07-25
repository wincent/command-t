/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef COMMANDT_H
#define COMMANDT_H

#include <stdbool.h> /* for bool */
#include <stddef.h> /* for size_t */
#include <stdint.h> /* for uint32_t */

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
    /**
     * Number of candidates currently stored in the scanner.
     */
    unsigned count;

    str_t *candidates;

    /**
     * @internal
     *
     * Book-keeping detail, needed for call to `munmap()`.
     */
    size_t candidates_size;

    /**
     * @internal
     *
     * Book-keeping detail, needed for call to `munmap()`.
     */
    char *buffer;

    /**
     * @internal
     *
     * Book-keeping detail, needed for call to `munmap()`.
     */
    size_t buffer_size;

    /**
     * @internal
     *
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
    bool ignore_case;
    bool ignore_spaces;
    bool never_show_dot_files;
    bool recurse;
    bool smart_case;
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

typedef struct {
    // Will roll-over in 2038, and as we're only using this for benchmarks, we
    // don't care.
    uint32_t seconds;
    uint32_t microseconds;
} benchmark_t;

/**
 * For benchmarking, returns number of seconds and microseconds since the epoch.
 *
 * Wrapper around `clock_gettime()`, because Lua's own `os.time()` only returns
 * integral numbers of seconds.
 */
benchmark_t commandt_epoch();

/**
 * Return number of processors on the current machine.
 */
unsigned commandt_processors();

#endif
