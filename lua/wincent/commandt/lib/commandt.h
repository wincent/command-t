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
 * @internal
 *
 * Represents a single "haystack" (ie. a string to be searched for the needle).
 */
typedef struct {
    str_t *candidate;
    uint32_t bitmask;
    float score;

    /**
     * Index of the leftmost "forbidden" dot (a "." beginning a hidden path
     * component: at index 0 or immediately after a "/"), or -1 if there is none;
     * the sentinel -2 means "not yet computed". This is a property of the
     * candidate alone, so it is computed lazily once and cached for reuse across
     * searches (including repeated empty-query passes during streaming).
     */
    ssize_t first_dot;
} haystack_t;

/**
 * How a scanner produces its candidates.
 */
typedef enum {
    /**
     * All candidates are present by the time the scanner is returned (the copy,
     * str, file, and synchronous exec scanners). There is nothing to produce.
     */
    SCANNER_EAGER = 0,

    /**
     * Candidates are produced asynchronously by a background thread reading from
     * a child process's stdout (see `commandt_scanner_new_exec_async()`).
     */
    SCANNER_EXEC,
} scanner_kind_t;

typedef struct {
    /**
     * Number of candidates currently stored in the scanner. For async scanners
     * this grows over time and is published/read with release/acquire ordering.
     */
    unsigned count;

    str_t *candidates;

    /**
     * @internal
     *
     * Book-keeping detail, needed for call to `munmap()`.
     */
    ssize_t candidates_size;

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
    ssize_t buffer_size;

    /**
     * @internal
     *
     * Maximum number of candidates the scanner may ever hold. Used to size the
     * matcher's `haystacks` slab up front so it never has to move.
     */
    unsigned capacity;

    /**
     * @internal
     *
     * Streaming/async production state.
     */
    int kind; // `scanner_kind_t`.

    /**
     * @internal
     *
     * Streaming/async production state.
     */
    int fd; // Read end of the child's stdout pipe, or -1.

    /**
     * @internal
     *
     * Streaming/async production state.
     */
    int pid; // Child PID, or -1.

    /**
     * @internal
     *
     * Streaming/async production state.
     */
    unsigned drop; // Leading characters to drop from each candidate.

    /**
     * @internal
     *
     * Streaming/async production state.
     */
    unsigned max_files; // Cap on candidate count, or 0 for unlimited.

    /**
     * @internal
     *
     * Streaming/async production state.
     */
    int done; // Non-zero once production has finished.

    /**
     * @internal
     *
     * Streaming/async production state.
     */
    void *thread; // Producer `pthread_t *`, or NULL.
} scanner_t;

/**
 * @internal
 *
 * Opaque, persistent per-matcher worker pool (defined in `matcher.c`).
 */
typedef struct matcher_pool matcher_pool_t;

/**
 * @internal
 *
 * The matcher's instance state.
 */
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
    bool smart_case;
    // bool sort;

    /**
     * Limit the number of returned results. Must be non-zero.
     */
    unsigned limit;
    unsigned threads;

    /**
     * The matcher owns a normalized copy of the caller's needle. These fields
     * provide the current query to `commandt_score()` and the workers. At the
     * end of a run, `last_needle` takes ownership of the copy for incremental
     * narrowing; `needle` aliases it until the next run. The retained copy is
     * freed when invalidated, replaced, or when the matcher is freed.
     */
    const char *needle;
    size_t needle_length;
    uint32_t needle_bitmask;

    const char *last_needle;
    size_t last_needle_length;

    /**
     * `haystacks` is a slab sized to the scanner's capacity; `haystacks_size` is
     * its byte size (for `munmap()`) and `initialized` tracks how many entries
     * have been set up so far (the rest are set up lazily as an async scanner
     * streams more candidates in).
     */
    size_t haystacks_size;
    unsigned initialized;

    /**
     * Persistent worker pool (see `matcher_pool_t`), reused across every run.
     * `NULL` when the matcher is configured for a single thread (there are no
     * background workers to pool).
     */
    matcher_pool_t *pool;
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
