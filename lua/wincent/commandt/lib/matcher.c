/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <assert.h> /* for assert */
#include <pthread.h> /* for pthread_create, pthread_join etc */
#include <stdbool.h> /* for bool */
#include <stddef.h> /* for size_t */
#include <stdlib.h> /* for qsort(), NULL */
#include <string.h> /* for strncmp() */

#include "commandt.h"
#include "debug.h"
#include "die.h"
#include "heap.h"
#include "matcher.h"
#include "scanner.h"
#include "score.h"
#include "str.h" /* for str_t */
#include "xmalloc.h"

// Avoid the overhead of threading when search space is small.
#define THREAD_THRESHOLD 1000

// Arbitrary limit to stop people from doing self-harm.
#define MAX_THREADS 128

typedef struct {
    unsigned worker_count;
    unsigned worker_index;
    matcher_t *matcher;

    // May need to temporarily override matcher as a result of smart_case.
    bool ignore_case;
} worker_args_t;

// Forward declarations.
static long calculate_bitmask(const char *str, unsigned long length);
static int cmp_alpha(const void *a, const void *b);
static int cmp_alpha_p(const void *a, const void *b);
static int cmp_score(const void *a, const void *b);
static int cmp_score_p(const void *a, const void *b);
static void *get_matches(void *worker_args);

matcher_t *commandt_matcher_new(
    scanner_t *scanner,
    bool always_show_dot_files,
    bool ignore_case,
    bool ignore_spaces,
    unsigned limit,
    bool never_show_dot_files,
    bool recurse,
    bool smart_case,
    uint64_t threads
) {
    assert(limit > 0);
    assert(threads > 0);
    if (threads > MAX_THREADS) {
        threads = MAX_THREADS;
    }

    matcher_t *matcher = xmalloc(sizeof(matcher_t));
    matcher->scanner = scanner;
    matcher->haystacks = xmalloc(scanner->count * sizeof(haystack_t));

    for (unsigned i = 0; i < scanner->count; i++) {
        matcher->haystacks[i].candidate = &scanner->candidates[i];
        matcher->haystacks[i].bitmask = UNSET_BITMASK;
        matcher->haystacks[i].score = UNSET_SCORE;
    }

    matcher->always_show_dot_files = always_show_dot_files;
    matcher->ignore_case = ignore_case;
    matcher->ignore_spaces = ignore_spaces;
    matcher->never_show_dot_files = never_show_dot_files;
    matcher->recurse = recurse;
    matcher->smart_case = smart_case;
    matcher->limit = limit;
    matcher->threads = (unsigned int)threads;
    matcher->needle = NULL;
    matcher->needle_length = 0;
    matcher->needle_bitmask = UNSET_BITMASK;
    matcher->last_needle = NULL;
    matcher->last_needle_length = 0;

    return matcher;
}

void commandt_matcher_free(matcher_t *matcher) {
    // Note that we don't free the scanner here (the scanner's owner is
    // responsible for freeing it).
    free(matcher->haystacks);
    free((void *)matcher->last_needle);
    free(matcher);
}

result_t *commandt_matcher_run(matcher_t *matcher, const char *needle) {
    scanner_t *scanner = matcher->scanner;
    unsigned candidate_count = scanner->count;
    unsigned limit = matcher->limit;
    unsigned matches_count = 0;

    size_t needle_length = strlen(needle);
    char *needle_copy = xmalloc(needle_length + 1);
    strcpy(needle_copy, needle);

    // Downcase needle if required.
    bool ignore_case = matcher->ignore_case;

    if (matcher->ignore_case || matcher->smart_case) {
        for (size_t i = 0; i < needle_length; i++) {
            char c = needle_copy[i];
            if (c >= 'A' && c <= 'Z' ) {
                if (matcher->smart_case) {
                    ignore_case = false;
                    break;
                } else {
                    needle_copy[i] = c + 'a' - 'A'; // Add 32 to downcase.
                }
            }
        }
    }

    // Delete spaces from needle if required.
    if (matcher->ignore_spaces) {
        size_t src = 0;
        size_t dest = 0;
        while (src < needle_length) {
            char c = needle[src];
            if (c != ' ') {
                if (dest == src) {
                    dest++;
                } else {
                    needle_copy[dest++] = c;
                }
            }
            src++;
        }
        needle_copy[dest] = '\0';
        needle_length -= src - dest;
    }

    matcher->needle = needle_copy;
    matcher->needle_length = needle_length;

    if (matcher->last_needle) {
        // Will compare against previously computed haystack bitmasks.
        matcher->needle_bitmask = calculate_bitmask(matcher->needle, needle_length);

        // Check whether current search extends previous search; if so, we can
        // skip all the non-matches from last time without looking at them.
        bool is_extension = false;
        if (needle_length >= matcher->last_needle_length) {
            is_extension = true;
            unsigned long index = 0;
            while (index < matcher->last_needle_length) {
                if (matcher->needle[index] != matcher->last_needle[index]) {
                    is_extension = false;
                    break;
                }
                index++;
            }
        }
        if (!is_extension) {
            free((void *)matcher->last_needle);
            matcher->last_needle = NULL;
            matcher->last_needle_length = 0;
        }
    }

    unsigned worker_count = matcher->threads > 0 ? matcher->threads : 1;
    if (candidate_count < THREAD_THRESHOLD) {
        worker_count = 1;
    }

    // Get unsorted matches.

    haystack_t **matches = xmalloc(worker_count * limit * sizeof(haystack_t *));
    pthread_t *threads = xmalloc(worker_count * sizeof(pthread_t));
    worker_args_t *worker_args = xmalloc(worker_count * sizeof(worker_args_t));

    for (unsigned i = 0; i < worker_count; i++) {
        worker_args[i].worker_count = worker_count;
        worker_args[i].worker_index = i;
        worker_args[i].matcher = matcher;
        worker_args[i].ignore_case = ignore_case;

        if (i == worker_count - 1) {
            // For the last worker, we'll just use the main thread.
            heap_t *heap = get_matches(&worker_args[i]);
            memcpy(matches + matches_count, heap->entries, heap->count * sizeof(haystack_t *));
            matches_count += heap->count;
            heap_free(heap);
        } else {
            int err = pthread_create(&threads[i], NULL, get_matches, (void *)&worker_args[i]);
            if (err != 0) {
                die("phthread_create() failed", err);
            }
        }
    }

    for (long i = 0; i < worker_count - 1; i++) {
        heap_t *heap;
        int err = pthread_join(threads[i], (void **)&heap);
        if (err != 0) {
            die("phtread_join() failed", err);
        }
        memcpy(matches + matches_count, heap->entries, heap->count * sizeof(haystack_t *));
        matches_count += heap->count;
        heap_free(heap);
    }

    free(threads);
    free(worker_args);

    if (needle_length == 0 || (needle_length == 1 && matcher->needle[0] == '.')) {
        // Alphabetic order if search string is only "" or "."
        qsort(matches, matches_count, sizeof(haystack_t *), cmp_alpha_p);
    } else {
        qsort(matches, matches_count, sizeof(haystack_t *), cmp_score_p);
    }

    result_t *results = xmalloc(sizeof(result_t));
    unsigned count = matches_count > limit ? limit : matches_count;
    results->matches = xmalloc(count * sizeof(const char *));
    results->count = 0;

    for (long i = 0; i < count && results->count <= limit; i++) {
        if (matches[i]->score > 0.0f) {
            results->matches[results->count++] = matches[i]->candidate;
        }
    }

    free(matches);

    // Save this state to potentially speed subsequent searches.
    free((void *)matcher->last_needle);
    matcher->last_needle = matcher->needle;
    matcher->last_needle_length = needle_length;

    return results;
}

void commandt_result_free(result_t *result) {
    free(result->matches);
    free(result);
}

static long calculate_bitmask(const char *str, unsigned long length) {
    long mask = 0;
    for (unsigned long i = 0; i < length; i++) {
        if (str[i] >= 'a' && str[i] <= 'z') {
            mask |= (1 << (str[i] - 'a'));
        } else if (str[i] >= 'A' && str[i] <= 'Z') {
            mask |= (1 << (str[i] - 'A'));
        }
    }
    return mask;
}

/**
 * Comparison function for use with `heap_new()`.
 */
static int cmp_alpha(const void *a, const void *b) {
    str_t *a_str = ((haystack_t *)a)->candidate;
    str_t *b_str = ((haystack_t *)b)->candidate;
    const char *a_ptr = a_str->contents;
    const char *b_ptr = b_str->contents;
    size_t a_len = a_str->length;
    size_t b_len = b_str->length;
    int order = strncmp(a_ptr, b_ptr, b_len);
    if (order == 0) {
        return a_len - b_len; // Shorter string wins.
    } else {
        return order;
    }
}

/**
 * Comparison function for use with `heap_new()`.
 */
static int cmp_score(const void *a, const void *b) {
    float a_score = ((haystack_t *)a)->score;
    float b_score = ((haystack_t *)b)->score;
    if (a_score > b_score) {
        return -1; // `a` should appear before `b`.
    } else if (a_score < b_score) {
        return 1;  // `b` should appear before `a`.
    } else {
        return cmp_alpha(a, b);
    }
}

/**
 * Comparison function for use with `qsort()`.
 */
static int cmp_alpha_p(const void *a, const void *b) {
    haystack_t *a_haystack = *((haystack_t **)a);
    haystack_t *b_haystack = *((haystack_t **)b);
    return cmp_alpha(a_haystack, b_haystack);
}

/**
 * Comparison function for use with `qsort()`.
 */
static int cmp_score_p(const void *a, const void *b) {
    haystack_t *a_haystack = *((haystack_t **)a);
    haystack_t *b_haystack = *((haystack_t **)b);
    return cmp_score(a_haystack, b_haystack);
}

static void *get_matches(void *worker_args) {
    unsigned worker_count = ((worker_args_t *)worker_args)->worker_count;
    unsigned worker_index = ((worker_args_t *)worker_args)->worker_index;
    matcher_t *matcher = ((worker_args_t *)worker_args)->matcher;
    bool ignore_case = ((worker_args_t *)worker_args)->ignore_case;

    // Reserve one extra slot so that we can do an insert-then-extract even
    // when "full" (effectively allows use of min-heap to maintain a
    // top-"limit" list of items).
    heap_t *heap = heap_new(matcher->limit + 1, cmp_score);

    // TODO benchmark different thread partitioning method
    // (intead of every nth item to a thread, break into blocks)
    // to see if cache characteristics improve the speed)
    for (unsigned i = worker_index; i < matcher->scanner->count; i += worker_count) {
        haystack_t *haystack = matcher->haystacks + i;
        if (matcher->needle_bitmask == UNSET_BITMASK) {
            haystack->bitmask = UNSET_BITMASK;
        }
        if (matcher->last_needle != NULL && haystack->score == 0.0f) {
            // Skip over this candidate because it didn't match last
            // time and it can't match this time either.
            continue;
        }

        haystack->score = commandt_score(haystack, matcher, ignore_case);

        if (haystack->score == 0.0f) {
            continue;
        }

        if (heap->count == matcher->limit) {
            float score = ((haystack_t *)HEAP_PEEK(heap))->score;
            if (haystack->score >= score) {
                heap_insert(heap, haystack);
                (void)heap_extract(heap);
            }
        } else {
            heap_insert(heap, haystack);
        }
    }

    return heap;
}
