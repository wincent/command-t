// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <pthread.h> /* for pthread_create, pthread_join etc */
#include <stdbool.h> /* for bool */
#include <stdlib.h> /* for qsort(), NULL */
#include <string.h> /* for strncmp() */

#include "commandt.h"
#include "die.h"
#include "heap.h"
#include "match.h"
#include "matcher.h"
#include "scanner.h"
#include "xmalloc.h"

#define THREAD_THRESHOLD 1000 /* avoid the overhead of threading when search space is small */

// TODO figure out overlap here between scanner_t and this
typedef struct {
    int count;
    haystack_t **haystacks;
} corpus_t;

typedef struct {
    int thread_count;
    int thread_index;
    bool case_sensitive;
    unsigned limit;
    corpus_t *corpus;
    const char *needle;
    unsigned long needle_length;
    const char *last_needle;
    unsigned long last_needle_length;
    bool always_show_dot_files;
    bool never_show_dot_files;
    bool recurse;
    long needle_bitmask;
} thread_args_t;

// Forward declarations.
static long calculate_bitmask(const char *str);
static int cmp_alpha(const void *a, const void *b);
static int cmp_score(const void *a, const void *b);
static void *match_thread(void *thread_args);

/**
 * Returns a new matcher, or NULL on failure.
 */
matcher_t *commandt_matcher_new(
    scanner_t *scanner,
    bool always_show_dot_files,
    bool never_show_dot_files
) {
    matcher_t *matcher = xmalloc(sizeof(matcher_t));
    matcher->scanner = scanner;

    // TODO: sort out which ones should be passed in at init time and which ones
    // later... should be consistent
    matcher->always_show_dot_files = always_show_dot_files;
    matcher->never_show_dot_files = never_show_dot_files;

    // Defaults.
    // TODO: provide a way to override these (either setters or passed in to
    // to commandt_matcher_run())
    matcher->case_sensitive = true; // TODO maybe consider doing smart case at this level (currently doing it at ruby level)
    matcher->ignore_spaces = true;
    matcher->last_needle = NULL;
    matcher->last_needle_length = 0;
    matcher->limit = 15;
    matcher->recurse = true;
    matcher->sort = true;
    matcher->threads = 4; // TODO: base on core count

    return matcher;
}

result_t *commandt_matcher_run(matcher_t *matcher, const char *needle) {
    long i, j, candidate_count;
    unsigned limit, thread_count;
    long err;
    pthread_t *threads;
    long needle_bitmask = UNSET_BITMASK;
    long heap_matches_count;
    bool use_heap;
    bool sort;
    corpus_t *corpus;
    // TODO: see if i can get away with sharing the corpus
    // (i may not be able to, because sorting may destroy info)
    corpus_t *heap_corpus;
    heap_t *heap;
    thread_args_t *thread_args;
    // TODO: may end up inlining many of these
    bool always_show_dot_files = matcher->always_show_dot_files;
    bool case_sensitive = matcher->case_sensitive;
    bool recurse = matcher->recurse;
    bool ignore_spaces = matcher->ignore_spaces;
    bool never_show_dot_files = matcher->never_show_dot_files;

    limit = matcher->limit;
    sort = matcher->sort != false;
    use_heap = limit && sort;
    heap_matches_count = 0;

    unsigned long needle_length = strlen(needle);

    if (!case_sensitive) {
        // TODO: implement (downcase needle)
    }

    if (ignore_spaces) {
        // TODO: implement (delete spaces from needle)
    }

    // Get unsorted matches.
    scanner_t *scanner = matcher->scanner;

    const char **candidates = scanner->candidates;
    candidate_count = scanner->count;

    // TODO: implement actual test here, to re-use previous matches data
    // structure if paths haven't changed...
    if (true) {
        // TODO: update this next comment
        // `paths` changed, need to replace matches array.
        corpus_t *corpus = xmalloc(sizeof(corpus_t));
        corpus->haystacks = xmalloc(candidate_count * sizeof(void *));

        // TODO: sigh; way to much allocation here, this is going to be super slow
        for (i = 0; i < candidate_count; i++) {
            corpus->haystacks[i] = xmalloc(sizeof(haystack_t));
            corpus->haystacks[i]->candidate = candidates[i];
            corpus->haystacks[i]->bitmask = UNSET_BITMASK;
            corpus->haystacks[i]->index = i;
            corpus->haystacks[i]->length = strlen(candidates[i]); // TODO avoid
            corpus->haystacks[i]->score = 1.0; // TODO: default to 0? 1? -1?
        }

        /* wrapped_matches = Data_Wrap_Struct( */
        /*     rb_cObject, */
        /*     0, */
        /*     free, */
        /*     matches */
        /* ); */
        /* rb_ivar_set(self, rb_intern("matches"), wrapped_matches); */
        matcher->last_needle = NULL;
        matcher->last_needle_length = 0;
    } else {
        // Get existing array.
        /* Data_Get_Struct( */
        /*     rb_ivar_get(self, rb_intern("matches")), */
        /*     haystack_t, */
        /*     matches */
        /* ); */

        // Will compare against previously computed haystack bitmasks.
        needle_bitmask = calculate_bitmask(needle);

        // Check whether current search extends previous search; if so, we can
        // skip all the non-matches from last time without looking at them.
        // TODO: implement (roll into calculate_bitmask check? probably inline
        // it here so that i don't have to come up with a name for it)
        /* if (rb_funcall(needle, rb_intern("start_with?"), 1, last_needle) != Qtrue) { */
        /*     matcher->last_needle = NULL; */
        /*     matcher->last_needle_length = 0; */
        /* } */
    }

    thread_count = matcher->threads > 0 ? matcher->threads : 1;
    if (use_heap) {
        corpus_t *heap_corpus = xmalloc(sizeof(corpus_t));
        heap_corpus->haystacks = xmalloc(thread_count * limit * sizeof(void *));

        // TODO: this is copy pasta and probably wrong... 
        // (i don't think we need it, we initialize one item at a time)
        /* for (i = 0; i < candidate_count; i++) { */
        /*     heap_corpus->haystacks[i] = xmalloc(sizeof(haystack_t)); */
        /*     heap_corpus->haystacks[i]->candidate = candidates[i]; */
        /*     heap_corpus->haystacks[i]->bitmask = UNSET_BITMASK; */
        /*     heap_corpus->haystacks[i]->index = i; */
        /*     heap_corpus->haystacks[i]->length = strlen(candidates[i]); // TODO avoid */
        /*     heap_corpus->haystacks[i]->score = 1.0; // TODO: default to 0? 1? -1? */
        /* } */
    }

    if (candidate_count < THREAD_THRESHOLD) {
        thread_count = 1;
    }

    threads = xmalloc(sizeof(pthread_t) * thread_count);
    thread_args = xmalloc(sizeof(thread_args_t) * thread_count);

    for (i = 0; i < thread_count; i++) {
        // TODO: probably just move matcher into thread args...
        thread_args[i].thread_count = thread_count;
        thread_args[i].thread_index = i;
        thread_args[i].case_sensitive = case_sensitive;
        thread_args[i].limit = use_heap ? limit : 0;
        thread_args[i].corpus = corpus;
        thread_args[i].needle = needle;
        thread_args[i].needle_length = needle_length;
        thread_args[i].last_needle = matcher->last_needle;
        thread_args[i].last_needle_length = matcher->last_needle_length;
        thread_args[i].always_show_dot_files = always_show_dot_files;
        thread_args[i].never_show_dot_files = never_show_dot_files;
        thread_args[i].recurse = recurse;
        thread_args[i].needle_bitmask = needle_bitmask;

        if (i == thread_count - 1) {
            // For the last "worker", we'll just use the main thread.
            heap = match_thread(&thread_args[i]);
            if (heap) {
                for (j = 0; j < heap->count; j++) {
                    heap_corpus->haystacks[heap_matches_count++] = (haystack_t *)heap->entries[j];
                }
                heap_free(heap);
            }
        } else {
            err = pthread_create(&threads[i], NULL, match_thread, (void *)&thread_args[i]);
            if (err != 0) {
                die("phthread_create() failed", err);
            }
        }
    }

    for (i = 0; i < thread_count - 1; i++) {
        err = pthread_join(threads[i], (void **)&heap);
        if (err != 0) {
            die("phtread_join() failed", err);
        }
        if (heap) {
            for (j = 0; j < heap->count; j++) {
                heap_corpus->haystacks[heap_matches_count++] = (haystack_t *)heap->entries[j];
            }
            heap_free(heap);
        }
    }
    free(threads);

    if (sort) {
        if (
            needle_length == 0 ||
            (needle_length == 1 && needle[0] == '.')
        ) {
            // Alphabetic order if search string is only "" or "."
            // TODO: make those semantics fully apply to heap case as well
            // (they don't because the heap itself calls cmp_score, which means
            // that the items which stay in the top [limit] may (will) be
            // different).
            qsort(
                use_heap ? heap_corpus : corpus,
                use_heap ? heap_matches_count : candidate_count,
                sizeof(haystack_t),
                cmp_alpha
            );
        } else {
            qsort(
                use_heap ? heap_corpus : corpus,
                use_heap ? heap_matches_count : candidate_count,
                sizeof(haystack_t),
                cmp_score
            );
        }
    }

    if (limit == 0) {
        // TODO: check whether we still want to do this (limit 0 = no limit)
        limit = candidate_count;
    }

    result_t *results = xmalloc(sizeof(result_t));
    results->indices = xmalloc(limit * sizeof(long));

    for (
        i = 0;
        i < (use_heap ? heap_matches_count : candidate_count) && limit > 0;
        i++
    ) {
        if ((use_heap ? heap_corpus : corpus)->haystacks[i]->score > 0.0) {
            results->indices[i] = (use_heap ? heap_corpus : corpus)->haystacks[i]->index;
            limit--;
        }
    }

    if (use_heap) {
        free(heap_corpus);
    }

    // Save this state to potentially speed subsequent searches.
    matcher->last_needle = needle;
    matcher->last_needle_length = needle_length;

    return results;
}

void commandt_result_free(result_t *result) {
    free(result->indices);
    free(result);
}

result_t *commandt_temporary_demo_function() {
    scanner_t *scanner = xmalloc(sizeof(scanner_t));
    scanner->candidates = xmalloc(5 * sizeof(void *));
    scanner->count = 5;
    scanner->version = 0;
    scanner->candidates[0] = "thing";
    scanner->candidates[1] = "foo";
    scanner->candidates[2] = "a longer string";
    scanner->candidates[3] = "some stuff like this";
    scanner->candidates[4] = "and some s t u f f like that";
    matcher_t *matcher = commandt_matcher_new(scanner, true, false);
    return commandt_matcher_run(matcher, "stuff");
}

static long calculate_bitmask(const char *str) {
    unsigned long len = strlen(str);
    unsigned long i;
    long mask = 0;
    for (i = 0; i < len; i++) {
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
    haystack_t a_match = *(haystack_t *)a;
    haystack_t b_match = *(haystack_t *)b;
    const char *a_ptr = a_match.candidate;
    const char *b_ptr = b_match.candidate;
    long a_len = a_match.length;
    long b_len = b_match.length;
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
    haystack_t a_match = *(haystack_t *)a;
    haystack_t b_match = *(haystack_t *)b;

    if (a_match.score > b_match.score) {
        return -1; // a scores higher, a should appear sooner.
    } else if (a_match.score < b_match.score) {
        return 1;  // b scores higher, a should appear later.
    } else {
        return cmp_alpha(a, b);
    }
}

static void *match_thread(void *thread_args) {
    long i;
    float score;
    heap_t *heap = NULL;
    thread_args_t *args = (thread_args_t *)thread_args;

    if (args->limit) {
        // Reserve one extra slot so that we can do an insert-then-extract even
        // when "full" (effectively allows use of min-heap to maintain a
        // top-"limit" list of items).
        heap = heap_new(args->limit + 1, cmp_score);
    }

    // TODO benchmark different thread partitioning method
    // (intead of every nth item to a thread, break into blocks)
    // to see if cache characteristics improve the speed)
    for (
        i = args->thread_index;
        i < args->corpus->count;
        i += args->thread_count
    ) {
        haystack_t *match = args->corpus->haystacks[i];
        if (args->needle_bitmask == UNSET_BITMASK) {
            match->bitmask = UNSET_BITMASK;
        }
        if (args->last_needle != NULL && match->score == 0.0) {
            // Skip over this candidate because it didn't match last
            // time and it can't match this time either.
            continue;
        }
        // TODO: think about having commandt_calculate_match just update the
        // score in-place
        match->score = commandt_calculate_match(
            match,
            args->needle,
            // TODO pass in length here to avoid a strlen (do it once here)
            args->case_sensitive,
            args->always_show_dot_files,
            args->never_show_dot_files,
            args->recurse,
            args->needle_bitmask
        );
        if (match->score == 0.0) {
            continue;
        }
        if (heap) {
            if (heap->count == args->limit) {
                score = ((haystack_t *)HEAP_PEEK(heap))->score;
                if (match->score >= score) {
                    heap_insert(heap, match);
                    (void)heap_extract(heap);
                }
            } else {
                heap_insert(heap, match);
            }
        }
    }

    return heap;
}
