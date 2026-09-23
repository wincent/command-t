/**
 * SPDX-FileCopyrightText: Copyright 2010-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "matcher.h"

#include <assert.h> /* for assert */
#include <pthread.h> /* for pthread_create, pthread_join etc */
#include <stdatomic.h> /* for atomic_bool, atomic_load_explicit(), atomic_store_explicit() */
#include <stdbool.h> /* for bool */
#include <stddef.h> /* for size_t */
#include <stdlib.h> /* for posix_memalign(), qsort(), NULL */
#include <string.h> /* for memcpy(), strcpy(), strlen() */

#ifdef __APPLE__
#include <dispatch/dispatch.h> /* for dispatch_semaphore_t and friends */
#else
#include <errno.h> /* for errno, EINTR */
#include <semaphore.h> /* for sem_t, sem_init(), sem_post(), sem_wait() */
#endif

#include "commandt.h" /* for haystack_t, matcher_t, scanner_t */
#include "compare.h" /* for commandt_cmp_alpha(), commandt_cmp_score() */
#include "die.h" /* for die() */
#include "heap.h" /* for HEAP_PEEK(), heap_free(), heap_insert(), heap_new(), heap_replace_top() */
#include "score.h" /* for commandt_score() */
#include "str.h" /* for str_t */
#include "xmalloc.h" /* for xmalloc() */
#include "xmap.h" /* for xmap(), xmunmap() */

// Avoid the overhead of threading when search space is small.
#define THREAD_THRESHOLD 1000

// Arbitrary limit to stop people from doing self-harm.
#define MAX_THREADS 128

// Cache line size used to pad the per-worker pool slots so that one worker
// writing its results never invalidates a neighbouring worker's (or the main
// thread's) cache line. 128 bytes covers Apple Silicon's 128-byte cache lines
// (and hardware prefetch pairing); it is harmless over-padding on x86-64's
// 64-byte lines.
#define CACHELINE 128

typedef struct {
    unsigned worker_count;
    unsigned worker_index;
    matcher_t *matcher;

    // May need to temporarily override matcher as a result of smart_case.
    bool ignore_case;

    // Snapshot of the scanner's candidate count for this run (an async scanner's
    // count may keep growing, but a single run works against a fixed snapshot).
    unsigned candidate_count;
} worker_args_t;

// A one-shot wake primitive (a binary semaphore) used to build the matcher's
// fork/join barrier. Every edge is single-producer/single-consumer, so there is
// never any lock contention: the main thread posts `go` and a worker waits on
// it; the worker posts `done` and the main thread waits on it. POSIX unnamed
// semaphores are unsupported on macOS (`sem_init()` fails with `ENOSYS`), so we
// use a GCD dispatch semaphore there and a POSIX semaphore everywhere else.
#ifdef __APPLE__
typedef dispatch_semaphore_t signal_t;

static inline void signal_init(signal_t *signal) {
    *signal = dispatch_semaphore_create(0);
}

static inline void signal_destroy(signal_t *signal) {
    dispatch_release(*signal);
}

static inline void signal_post(signal_t *signal) {
    dispatch_semaphore_signal(*signal);
}

static inline void signal_wait(signal_t *signal) {
    dispatch_semaphore_wait(*signal, DISPATCH_TIME_FOREVER);
}
#else
typedef sem_t signal_t;

static inline void signal_init(signal_t *signal) {
    if (sem_init(signal, 0, 0) != 0) {
        die("sem_init() failed", errno);
    }
}

static inline void signal_destroy(signal_t *signal) {
    sem_destroy(signal);
}

static inline void signal_post(signal_t *signal) {
    if (sem_post(signal) != 0) {
        die("sem_post() failed", errno);
    }
}

static inline void signal_wait(signal_t *signal) {
    // `sem_wait()` can return early if interrupted by a signal; just retry.
    while (sem_wait(signal) != 0) {
        if (errno == EINTR) {
            continue;
        }
        die("sem_wait() failed", errno);
    }
}
#endif

// A single pooled worker. `commandt_matcher_run()` publishes `args` while the
// worker is parked (so no lock is needed), posts `go`, and later waits on
// `done` before reading `result`. The semaphore posts/waits provide the
// release/acquire ordering that makes those writes visible across threads.
typedef struct {
    // Pad each slot onto its own cache line to avoid false sharing between
    // workers (and the main thread) as they write `args`/`result`.
    _Alignas(CACHELINE) worker_args_t args;
    heap_t *result;
    signal_t go;
    signal_t done;
    pthread_t thread;
    matcher_pool_t *pool;
} pool_worker_t;

// A persistent pool of background workers, created once per matcher and reused
// across every run. The main thread always handles the final stripe itself, so
// the pool only holds `matcher->threads - 1` background threads.
struct matcher_pool {
    unsigned worker_count;
    atomic_bool shutdown;
    pool_worker_t workers[];
};

// Forward declarations.
static uint32_t calculate_bitmask(const char *str, unsigned long length);
static int cmp_alpha_p(const void *a, const void *b);
static int cmp_score_p(const void *a, const void *b);
static heap_t *get_matches(const worker_args_t *worker_args);
static matcher_pool_t *pool_create(unsigned worker_count);
static void pool_destroy(matcher_pool_t *pool);
static void *pool_worker_run(void *arg);

static void *pool_worker_run(void *arg) {
    pool_worker_t *worker = arg;
    for (;;) {
        signal_wait(&worker->go);
        if (atomic_load_explicit(&worker->pool->shutdown, memory_order_acquire)) {
            break;
        }
        worker->result = get_matches(&worker->args);
        signal_post(&worker->done);
    }
    return NULL;
}

static matcher_pool_t *pool_create(unsigned worker_count) {
    size_t size =
        sizeof(matcher_pool_t) + (size_t)worker_count * sizeof(pool_worker_t);

    // `malloc()` only guarantees `max_align_t` alignment, but the per-worker
    // slots are over-aligned to a cache line, so allocate to that boundary.
    matcher_pool_t *pool = NULL;
    int err = posix_memalign((void **)&pool, CACHELINE, size);
    if (err != 0) {
        die("posix_memalign() failed", err);
    }

    pool->worker_count = worker_count;
    atomic_store_explicit(&pool->shutdown, false, memory_order_relaxed);

    for (unsigned i = 0; i < worker_count; i++) {
        pool_worker_t *worker = &pool->workers[i];
        worker->pool = pool;
        worker->result = NULL;
        signal_init(&worker->go);
        signal_init(&worker->done);
        err = pthread_create(&worker->thread, NULL, pool_worker_run, worker);
        if (err != 0) {
            die("pthread_create() failed", err);
        }
    }

    return pool;
}

static void pool_destroy(matcher_pool_t *pool) {
    if (!pool) {
        return;
    }

    // Ask every worker to exit, then wait for and clean up each one. Like every
    // other matcher entry point this only runs on the single owning thread with
    // no run in flight, so the workers are guaranteed to be parked on `go`.
    atomic_store_explicit(&pool->shutdown, true, memory_order_release);
    for (unsigned i = 0; i < pool->worker_count; i++) {
        signal_post(&pool->workers[i].go);
    }
    for (unsigned i = 0; i < pool->worker_count; i++) {
        pthread_join(pool->workers[i].thread, NULL);
        signal_destroy(&pool->workers[i].go);
        signal_destroy(&pool->workers[i].done);
    }

    free(pool);
}

matcher_t *commandt_matcher_new(
    scanner_t *scanner,
    bool always_show_dot_files,
    bool ignore_case,
    bool ignore_spaces,
    unsigned limit,
    bool never_show_dot_files,
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

    // Size the haystacks slab to the scanner's capacity so it never has to move
    // as an async scanner streams more candidates in; it is a sparse mmap, so
    // the reservation only costs physical memory for entries actually touched.
    unsigned capacity = scanner->capacity;
    matcher->haystacks_size = (size_t)capacity * sizeof(haystack_t);
    matcher->haystacks = capacity ? xmap(matcher->haystacks_size) : NULL;

    unsigned count = __atomic_load_n(&scanner->count, __ATOMIC_ACQUIRE);
    for (unsigned i = 0; i < count; i++) {
        matcher->haystacks[i].candidate = &scanner->candidates[i];
        matcher->haystacks[i].bitmask = UNSET_HAYSTACK_BITMASK;
        matcher->haystacks[i].score = UNSET_SCORE;
        matcher->haystacks[i].first_dot = -2;
    }
    matcher->initialized = count;

    matcher->always_show_dot_files = always_show_dot_files;
    matcher->ignore_case = ignore_case;
    matcher->ignore_spaces = ignore_spaces;
    matcher->never_show_dot_files = never_show_dot_files;
    matcher->smart_case = smart_case;
    matcher->limit = limit;
    matcher->threads = (unsigned int)threads;
    matcher->needle = NULL;
    matcher->needle_length = 0;
    matcher->needle_bitmask = UNSET_NEEDLE_BITMASK;
    matcher->last_needle = NULL;
    matcher->last_needle_length = 0;

    // Create the persistent worker pool once, here, rather than spawning and
    // joining threads on every `commandt_matcher_run()`. The main thread always
    // handles the final stripe itself, so the pool only needs `threads - 1`
    // background workers; a single-threaded matcher needs none.
    matcher->pool =
        matcher->threads > 1 ? pool_create(matcher->threads - 1) : NULL;

    return matcher;
}

void commandt_matcher_free(matcher_t *matcher) {
    // Note that we don't free the scanner here (the scanner's owner is
    // responsible for freeing it).
    pool_destroy(matcher->pool);
    if (matcher->haystacks && matcher->haystacks_size) {
        xmunmap(matcher->haystacks, matcher->haystacks_size);
    }
    free((void *)matcher->last_needle);
    free(matcher);
}

result_t *commandt_matcher_run(matcher_t *matcher, const char *needle) {
    scanner_t *scanner = matcher->scanner;
    unsigned candidate_count = __atomic_load_n(&scanner->count, __ATOMIC_ACQUIRE);
    unsigned limit = matcher->limit;
    unsigned matches_count = 0;

    // An async scanner may have streamed in more candidates since the last run
    // (or since `matcher_new()`); initialize their haystacks now. `count` only
    // grows and every entry below `candidate_count` is immutable, so no further
    // synchronization is needed.
    for (unsigned i = matcher->initialized; i < candidate_count; i++) {
        matcher->haystacks[i].candidate = &scanner->candidates[i];
        matcher->haystacks[i].bitmask = UNSET_HAYSTACK_BITMASK;
        matcher->haystacks[i].score = UNSET_SCORE;
        matcher->haystacks[i].first_dot = -2;
    }
    matcher->initialized = candidate_count;

    size_t needle_length = strlen(needle);
    char *needle_copy = xmalloc(needle_length + 1);
    strcpy(needle_copy, needle);

    // Downcase needle if required.
    bool ignore_case = matcher->ignore_case;

    if (matcher->ignore_case || matcher->smart_case) {
        for (size_t i = 0; i < needle_length; i++) {
            char c = needle_copy[i];
            if (c >= 'A' && c <= 'Z') {
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
            char c = needle_copy[src];
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
        matcher->needle_bitmask =
            calculate_bitmask(matcher->needle, needle_length);

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

    // Wake `worker_count - 1` pooled background workers to process their stripes
    // in parallel, then process the final stripe on this (the calling) thread
    // while they run. Because `commandt_matcher_run()` is only ever called from
    // a single thread (Neovim's main loop), the pool is quiescent on entry, so
    // we can publish each worker's arguments without a lock; the `go` post
    // carries the release barrier that makes them visible to the worker.
    matcher_pool_t *pool = matcher->pool;
    for (unsigned i = 0; i + 1 < worker_count; i++) {
        pool_worker_t *worker = &pool->workers[i];
        worker->args.worker_count = worker_count;
        worker->args.worker_index = i;
        worker->args.matcher = matcher;
        worker->args.ignore_case = ignore_case;
        worker->args.candidate_count = candidate_count;
        signal_post(&worker->go);
    }

    {
        // Final stripe (`worker_index == worker_count - 1`) on the main thread.
        worker_args_t main_args = {
            .worker_count = worker_count,
            .worker_index = worker_count - 1,
            .matcher = matcher,
            .ignore_case = ignore_case,
            .candidate_count = candidate_count,
        };
        heap_t *heap = get_matches(&main_args);
        unsigned offset = matches_count;
        matches_count += heap->count;
        memcpy(
            matches + offset, heap->entries, heap->count * sizeof(haystack_t *)
        );
        heap_free(heap);
    }

    // Collect each background worker's heap once it signals completion.
    for (unsigned i = 0; i + 1 < worker_count; i++) {
        pool_worker_t *worker = &pool->workers[i];
        signal_wait(&worker->done);
        heap_t *heap = worker->result;
        unsigned offset = matches_count;
        matches_count += heap->count;
        memcpy(
            matches + offset, heap->entries, heap->count * sizeof(haystack_t *)
        );
        heap_free(heap);
    }

    unsigned count = matches_count;
    if (needle_length == 0 || (needle_length == 1 && matcher->needle[0] == '.')) {
        // Alphabetic order if search string is only "" or "."
        qsort(matches, count, sizeof(haystack_t *), cmp_alpha_p);
    } else {
        qsort(matches, count, sizeof(haystack_t *), cmp_score_p);
    }

    result_t *results = xmalloc(sizeof(result_t));
    results->matches = xmalloc(limit * sizeof(const char *));
    results->match_count = 0;
    results->candidate_count = candidate_count;

    for (long i = 0; i < count && results->match_count < limit; i++) {
        if (matches[i]->score > 0.0f) {
            results->matches[results->match_count++] = matches[i]->candidate;
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

static uint32_t calculate_bitmask(const char *str, unsigned long length) {
    uint32_t mask = 0;
    for (unsigned long i = 0; i < length; i++) {
        unsigned char c = (unsigned char)str[i];
        if (c >= 'a' && c <= 'z') {
            mask |= UINT32_C(1) << (c - 'a');
        } else if (c >= 'A' && c <= 'Z') {
            mask |= UINT32_C(1) << (c - 'A');
        }
    }
    return mask;
}

/**
 * Comparison function for use with `qsort()`.
 */
static int cmp_alpha_p(const void *a, const void *b) {
    haystack_t *a_haystack = *((haystack_t **)a);
    haystack_t *b_haystack = *((haystack_t **)b);
    return commandt_cmp_alpha(a_haystack, b_haystack);
}

/**
 * Comparison function for use with `qsort()`.
 */
static int cmp_score_p(const void *a, const void *b) {
    haystack_t *a_haystack = *((haystack_t **)a);
    haystack_t *b_haystack = *((haystack_t **)b);
    return commandt_cmp_score(a_haystack, b_haystack);
}

static heap_t *get_matches(const worker_args_t *worker_args) {
    unsigned worker_count = worker_args->worker_count;
    unsigned worker_index = worker_args->worker_index;
    matcher_t *matcher = worker_args->matcher;
    bool ignore_case = worker_args->ignore_case;
    unsigned candidate_count = worker_args->candidate_count;
    size_t needle_length = matcher->needle_length;
    bool narrowing = matcher->last_needle != NULL;

    // The empty query and the lone "." query are ordered alphabetically;
    // otherwise we sort by score.
    bool sort_by_score =
        !(needle_length == 0 ||
          (needle_length == 1 && matcher->needle[0] == '.'));

    heap_t *heap = heap_new(matcher->limit);

    // Each worker will process a chunk of 64 consecutive needles at a time in
    // order maximize benefit of the CPU cache.
    unsigned chunk_size = 64;
    for (unsigned chunk_start = worker_index * chunk_size;
         chunk_start < candidate_count;
         chunk_start += worker_count * chunk_size) {
        unsigned chunk_end = chunk_start + chunk_size;
        if (chunk_end > candidate_count) {
            chunk_end = candidate_count;
        }
        for (unsigned i = chunk_start; i < chunk_end; i++) {
            haystack_t *haystack = matcher->haystacks + i;
            if (matcher->needle_bitmask == UNSET_NEEDLE_BITMASK) {
                haystack->bitmask = UNSET_HAYSTACK_BITMASK;
            }
            if (narrowing && haystack->score == 0.0f) {
                // Skip over this candidate because it didn't match last
                // time and it can't match this time either.
                continue;
            }

            // Once the heap is full (ie. `heap->count == matcher->limit`), the
            // smallest score it holds is the threshold a candidate must reach to
            // displace anything. Passing it to `commandt_score()` lets the
            // scorer abandon a candidate as soon as its best achievable score
            // provably falls short; a threshold of 0 means "score in full".
            float threshold = 0.0f;
            if (sort_by_score && heap->count == matcher->limit) {
                threshold = HEAP_PEEK(heap)->score;
                size_t candidate_length = haystack->candidate->length;
                if (candidate_length > 0) {
                    // `commandt_score_upper_bound()` gives the highest score any
                    // candidate of this length could achieve for this needle, so
                    // anything below the threshold can be skipped without
                    // scoring at all. Slack avoids false positives from
                    // floating-point rounding in the scorer.
                    float upper_bound = commandt_score_upper_bound(
                        needle_length, candidate_length
                    );
                    float slack = 1.0e-4f;
                    if (upper_bound * (1.0f + slack) < threshold) {
                        // We did not establish whether this candidate matches the
                        // current query. A stale zero would incorrectly mark it
                        // as a known non-match if the query is then extended.
                        if (!narrowing && haystack->score == 0.0f) {
                            haystack->score = UNSET_SCORE;
                        }
                        continue;
                    }
                }
            }

            haystack->score =
                commandt_score(haystack, matcher, ignore_case, threshold);

            if (haystack->score == 0.0f) {
                continue;
            }

            if (heap->count == matcher->limit) {
                // Full heap: replace the worst entry (root) in place if this
                // candidate beats it, avoiding an insert-then-extract.
                if (commandt_cmp_score(haystack, HEAP_PEEK(heap)) < 0) {
                    heap_replace_top(heap, haystack);
                }
            } else {
                heap_insert(heap, haystack);
            }
        }
    }

    return heap;
}
