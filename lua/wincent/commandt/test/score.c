/**
 * SPDX-FileCopyrightText: Copyright 2026-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "score.h"

#include <string.h> /* for strlen() */

#include "xmalloc.h"

static unsigned allocation_count;

static void *counted_malloc(size_t size) {
    allocation_count++;
    return commandt_xmalloc(size);
}

static void *counted_calloc(size_t count, size_t size) {
    allocation_count++;
    return commandt_xcalloc(count, size);
}

// Include the scorer here so only its allocator calls are counted. The wrappers
// still use the real allocators; no hooks are added to the shipped library.
#define commandt_xmalloc counted_malloc
#define commandt_xcalloc counted_calloc
#include "../lib/score.c"
#undef commandt_xmalloc
#undef commandt_xcalloc

unsigned commandt_test_allocation_count(void) {
    return allocation_count;
}

// Test-only FFI adapter. Each call starts with fresh candidate state and disables
// threshold pruning. The caller normalizes the query when ignore_case is true.
float commandt_test_score(
    const char *candidate,
    const char *needle,
    bool ignore_case,
    bool always_show_dot_files,
    bool never_show_dot_files
) {
    str_t string = {
        .contents = candidate,
        .length = strlen(candidate),
        .capacity = -1,
    };
    haystack_t haystack = {
        .candidate = &string,
        .bitmask = UNSET_HAYSTACK_BITMASK,
        .score = UNSET_SCORE,
        .first_dot = -2,
    };
    matcher_t matcher = {
        .needle = needle,
        .needle_length = strlen(needle),
        .needle_bitmask = UNSET_NEEDLE_BITMASK,
        .always_show_dot_files = always_show_dot_files,
        .never_show_dot_files = never_show_dot_files,
    };
    allocation_count = 0;
    return commandt_score(&haystack, &matcher, ignore_case, 0.0f);
}
