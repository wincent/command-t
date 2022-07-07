/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <assert.h> /* for assert */
#include <pthread.h> /* for pthread_create, pthread_join etc */
#include <stdbool.h> /* for bool */
#include <stdio.h> /* from printf() */
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

typedef struct {
    int thread_count;
    int thread_index;
    matcher_t *matcher;
} thread_args_t;

// Forward declarations.
static long calculate_bitmask(const char *str, unsigned long length);
static int cmp_alpha(const void *a, const void *b);
static int cmp_score(const void *a, const void *b);
static void *match_thread(void *thread_args);

matcher_t *commandt_matcher_new(
    scanner_t *scanner,
    bool always_show_dot_files,
    bool case_sensitive,
    bool ignore_spaces,
    unsigned limit,
    bool never_show_dot_files,
    bool recurse
) {
    assert(limit > 0);

    matcher_t *matcher = xmalloc(sizeof(matcher_t));
    matcher->scanner = scanner;
    matcher->haystacks = xmalloc(scanner->count * sizeof(haystack_t));

    for (size_t i = 0; i < scanner->count; i++) {
        matcher->haystacks[i].candidate = scanner->candidates[i];
        matcher->haystacks[i].bitmask = UNSET_BITMASK;
        matcher->haystacks[i].score = UNSET_SCORE;
    }

    matcher->always_show_dot_files = always_show_dot_files;
    matcher->case_sensitive = case_sensitive; // TODO maybe consider doing smart case at this level (currently doing it at Ruby/Lua level)
    matcher->ignore_spaces = ignore_spaces;
    matcher->never_show_dot_files = never_show_dot_files;
    matcher->recurse = recurse;
    matcher->limit = limit;
    matcher->threads = 4; // TODO: base on core count
    matcher->needle = NULL;
    matcher->needle_length = 0;
    matcher->needle_bitmask = UNSET_BITMASK;
    matcher->last_needle = NULL;
    matcher->last_needle_length = 0;

    return matcher;
}

void commandt_matcher_free(matcher_t *matcher) {
    // Note that we don't free the scanner here, as that is passed in when
    // creating the matcher (the scanner's owner is responsible for freeing it).
    free(matcher->haystacks);

    // NOTE: we don't "own" this one; we just keep it for book keeping. it
    // doesn't have to be durable...
    if (matcher->needle) {
        free((void *)matcher->needle);
    }

    if (matcher->last_needle) {
        free((void *)matcher->last_needle);
    }
    free(matcher);
}

result_t *commandt_matcher_run(matcher_t *matcher, const char *needle) {
    long i, j;
    scanner_t *scanner = matcher->scanner;
    long candidate_count = scanner->count;
    unsigned limit = matcher->limit;
    heap_t *heap;
    long matches_count = 0;

    // TODO: take ownership (copy) needle so that we can free it if needed
    // nah, only need to do that for last_needle

    // Downcase needle if required.
    if (!matcher->case_sensitive) {
        unsigned long length = strlen(needle);
        char *downcased = xmalloc(length + 1);
        for (unsigned long i = 0; i < length; i++) {
            char c = needle[i];
            if (c >= 'A' && c <= 'Z') {
                downcased[i] = c + 'a' - 'A'; // Add 32 to downcase.
            } else {
                downcased[i] = c;
            }
        }
        downcased[length] = '\0';
        needle = downcased; // TODO free when we're done with this
    }

    // Delete spaces from needle if required.
    if (matcher->ignore_spaces) {
        unsigned long length = strlen(needle);
        char *squished = xmalloc(length + 1);
        unsigned long src = 0;
        unsigned long dest = 0;
        while (src < length) {
            char c = needle[src++];
            if (c != ' ') {
                squished[dest++] = c;
            }
        }
        squished[dest] = '\0';
        needle = squished; // TODO free when we're done with this
    }

    unsigned long needle_length = strlen(needle);
    matcher->needle = needle;
    matcher->needle_length = needle_length;

    if (matcher->last_needle) {
        // Will compare against previously computed haystack bitmasks.
        matcher->needle_bitmask = calculate_bitmask(needle, needle_length);

        // Check whether current search extends previous search; if so, we can
        // skip all the non-matches from last time without looking at them.
        if (needle_length > matcher->last_needle_length) {
            unsigned long index = 0;
            while (index < matcher->last_needle_length) {
                if (needle[index] != matcher->last_needle[index]) {
                    matcher->last_needle = NULL;
                    matcher->last_needle_length = 0;
                    break;
                }
                index++;
            }
        }
    }

    unsigned thread_count = matcher->threads > 0 ? matcher->threads : 1;
    if (candidate_count < THREAD_THRESHOLD) {
        thread_count = 1;
    }

    // Get unsorted matches.

    haystack_t *matches = xmalloc(thread_count * limit * sizeof(haystack_t));
    pthread_t *threads = xmalloc(thread_count * sizeof(pthread_t));
    thread_args_t *thread_args = xmalloc(thread_count * sizeof(thread_args_t));

    for (i = 0; i < thread_count; i++) {
        thread_args[i].thread_count = thread_count;
        thread_args[i].thread_index = i;
        thread_args[i].matcher = matcher;

        if (i == thread_count - 1) {
            // For the last "worker", we'll just use the main thread.
            heap = match_thread(&thread_args[i]);
            if (heap) {
                for (j = 0; j < heap->count; j++) {
                    memcpy(matches + matches_count++, heap->entries[j], sizeof(haystack_t));
                }
                heap_free(heap);
            }
        } else {
            int err = pthread_create(&threads[i], NULL, match_thread, (void *)&thread_args[i]);
            if (err != 0) {
                die("phthread_create() failed", err);
            }
        }
    }

    for (i = 0; i < thread_count - 1; i++) {
        int err = pthread_join(threads[i], (void **)&heap);
        if (err != 0) {
            die("phtread_join() failed", err);
        }
        if (heap) {
            for (j = 0; j < heap->count; j++) {
                memcpy(matches + matches_count++, heap->entries[j], sizeof(haystack_t));
            }
            heap_free(heap);
        }
    }

    free(threads);
    free(thread_args);

    if (needle_length == 0 || (needle_length == 1 && needle[0] == '.')) {
        // Alphabetic order if search string is only "" or "."
        qsort(matches, matches_count, sizeof(haystack_t), cmp_alpha);
    } else {
        qsort(matches, matches_count, sizeof(haystack_t), cmp_score);
    }

    result_t *results = xmalloc(sizeof(result_t));
    unsigned count = matches_count > limit ? limit : matches_count;
    results->matches = xmalloc(count * sizeof(const char *));
    results->count = 0;

    for (i = 0; i < count && results->count <= limit; i++) {
        if (matches[i].score > 0.0) {
            results->matches[results->count++] = matches[i].candidate;
        }
    }

    free(matches);

    // Save this state to potentially speed subsequent searches.
    matcher->last_needle = needle; // BUG? could be leaking this?
    matcher->last_needle_length = needle_length;

    return results;
}

void commandt_result_free(result_t *result) {
    free(result->matches);
    free(result);
}

// TODO: make benchmarks to compare cost of passing in array of `str_t` from Lua
// side, vs passing in an array of `const char *` (and having to call `strlen()`
// on them all).
int commandt_temporary_demo_function(str_t **candidates, size_t count) {
    scanner_t *scanner = scanner_new(count);
    scanner_push_str(scanner, candidates, count);
    str_t *dump = scanner_dump(scanner);
    printf("\n\n\n%s\n\n\n", dump->contents);
    str_free(dump);
    return count;
}

void commandt_print_scanner(scanner_t *scanner) {
    str_t *dump = scanner_dump(scanner);
    fprintf(stderr, "\n\n\n%s\n\n\n", dump->contents);
    str_free(dump);
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
 * Comparison function for use with qsort.
 */
static int cmp_alpha(const void *a, const void *b) {
    haystack_t *a_match = (haystack_t *)a;
    haystack_t *b_match = (haystack_t *)b;
    const char *a_ptr = a_match->candidate->contents;
    const char *b_ptr = b_match->candidate->contents;
    long a_len = a_match->candidate->length;
    long b_len = b_match->candidate->length;
    int order = 0;

    if (a_len > b_len) {
        order = strncmp(a_ptr, b_ptr, b_len);
        if (order == 0)
            order = 1; // shorter string (b) wins.
    } else if (a_len < b_len) {
        order = strncmp(a_ptr, b_ptr, a_len);
        if (order == 0)
            order = -1; // shorter string (a) wins.
    } else {
        order = strncmp(a_ptr, b_ptr, a_len);
    }

    return order;
}

/**
 * Comparison function for use with qsort.
 */
static int cmp_score(const void *a, const void *b) {
    haystack_t *a_match = (haystack_t *)a;
    haystack_t *b_match = (haystack_t *)b;

    if (a_match->score > b_match->score) {
        return -1; // a scores higher, a should appear sooner.
    } else if (a_match->score < b_match->score) {
        return 1;  // b scores higher, a should appear later.
    } else {
        return cmp_alpha(a, b);
    }
}

static void *match_thread(void *thread_args) {
    size_t i;
    float score;
    thread_args_t *args = (thread_args_t *)thread_args;
    matcher_t *matcher = args->matcher;

    // Reserve one extra slot so that we can do an insert-then-extract even
    // when "full" (effectively allows use of min-heap to maintain a
    // top-"limit" list of items).
    heap_t *heap = heap_new(matcher->limit + 1, cmp_score);

    // TODO benchmark different thread partitioning method
    // (intead of every nth item to a thread, break into blocks)
    // to see if cache characteristics improve the speed)
    for (
        i = args->thread_index;
        i < matcher->scanner->count;
        i += args->thread_count
    ) {
        haystack_t *haystack = matcher->haystacks + i;
        if (matcher->needle_bitmask == UNSET_BITMASK) {
            haystack->bitmask = UNSET_BITMASK;
        }
        if (matcher->last_needle != NULL && haystack->score == 0.0) {
            // Skip over this candidate because it didn't match last
            // time and it can't match this time either.
            continue;
        }

        haystack->score = commandt_score(haystack, matcher);

        if (haystack->score == 0.0) {
            continue;
        }

        if (heap->count == matcher->limit) {
            score = ((haystack_t *)HEAP_PEEK(heap))->score;
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
