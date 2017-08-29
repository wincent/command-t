// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdlib.h>  /* for qsort() */
#include <string.h>  /* for strncmp() */
#include "match.h"
#include "matcher.h"
#include "heap.h"
#include "ext.h"
#include "ruby_compat.h"

// order matters; we want this to be evaluated only after ruby.h
#ifdef HAVE_PTHREAD_H
#include <pthread.h> /* for pthread_create, pthread_join etc */
#endif

// Comparison function for use with qsort.
int cmp_alpha(const void *a, const void *b) {
    match_t a_match = *(match_t *)a;
    match_t b_match = *(match_t *)b;
    VALUE   a_str   = a_match.path;
    VALUE   b_str   = b_match.path;
    char    *a_p    = RSTRING_PTR(a_str);
    long    a_len   = RSTRING_LEN(a_str);
    char    *b_p    = RSTRING_PTR(b_str);
    long    b_len   = RSTRING_LEN(b_str);
    int     order   = 0;

    if (a_len > b_len) {
        order = strncmp(a_p, b_p, b_len);
        if (order == 0)
            order = 1; // shorter string (b) wins.
    } else if (a_len < b_len) {
        order = strncmp(a_p, b_p, a_len);
        if (order == 0)
            order = -1; // shorter string (a) wins.
    } else {
        order = strncmp(a_p, b_p, a_len);
    }

    return order;
}

// Comparison function for use with qsort.
int cmp_score(const void *a, const void *b) {
    match_t a_match = *(match_t *)a;
    match_t b_match = *(match_t *)b;

    if (a_match.score > b_match.score) {
        return -1; // a scores higher, a should appear sooner.
    } else if (a_match.score < b_match.score) {
        return 1;  // b scores higher, a should appear later.
    } else {
        return cmp_alpha(a, b);
    }
}

VALUE CommandTMatcher_initialize(int argc, VALUE *argv, VALUE self) {
    VALUE always_show_dot_files;
    VALUE never_show_dot_files;
    VALUE options;
    VALUE scanner;

    // Process arguments: 1 mandatory, 1 optional.
    if (rb_scan_args(argc, argv, "11", &scanner, &options) == 1) {
        options = Qnil;
    }
    if (NIL_P(scanner)) {
        rb_raise(rb_eArgError, "nil scanner");
    }

    rb_iv_set(self, "@scanner", scanner);

    // Check optional options hash for overrides.
    always_show_dot_files = CommandT_option_from_hash("always_show_dot_files", options);
    never_show_dot_files = CommandT_option_from_hash("never_show_dot_files", options);

    rb_iv_set(self, "@always_show_dot_files", always_show_dot_files);
    rb_iv_set(self, "@never_show_dot_files", never_show_dot_files);

    return Qnil;
}

typedef struct {
    long thread_count;
    long thread_index;
    long case_sensitive;
    long limit;
    match_t *matches;
    long path_count;
    VALUE haystacks;
    VALUE needle;
    VALUE last_needle;
    VALUE always_show_dot_files;
    VALUE never_show_dot_files;
    VALUE recurse;
    long needle_bitmask;
} thread_args_t;

void *match_thread(void *thread_args) {
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

    for (
        i = args->thread_index;
        i < args->path_count;
        i += args->thread_count
    ) {
        args->matches[i].path = RARRAY_PTR(args->haystacks)[i];
        if (args->needle_bitmask == UNSET_BITMASK) {
            args->matches[i].bitmask = UNSET_BITMASK;
        }
        if (!NIL_P(args->last_needle) && args->matches[i].score == 0.0) {
            // Skip over this candidate because it didn't match last
            // time and it can't match this time either.
            continue;
        }
        args->matches[i].score = calculate_match(
            args->matches[i].path,
            args->needle,
            args->case_sensitive,
            args->always_show_dot_files,
            args->never_show_dot_files,
            args->recurse,
            args->needle_bitmask,
            &args->matches[i].bitmask
        );
        if (args->matches[i].score == 0.0) {
            continue;
        }
        if (heap) {
            if (heap->count == args->limit) {
                score = ((match_t *)HEAP_PEEK(heap))->score;
                if (args->matches[i].score >= score) {
                    heap_insert(heap, &args->matches[i]);
                    (void)heap_extract(heap);
                }
            } else {
                heap_insert(heap, &args->matches[i]);
            }
        }
    }

    return heap;
}

long calculate_bitmask(VALUE string) {
    char *str = RSTRING_PTR(string);
    long len = RSTRING_LEN(string);
    long i;
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

VALUE CommandTMatcher_sorted_matches_for(int argc, VALUE *argv, VALUE self)
{
    long i, j, limit, path_count, thread_count;
#ifdef HAVE_PTHREAD_H
    long err;
    pthread_t *threads;
#endif
    long needle_bitmask = UNSET_BITMASK;
    long heap_matches_count;
    int use_heap;
    int sort;
    match_t *matches;
    match_t *heap_matches = NULL;
    heap_t *heap;
    thread_args_t *thread_args;
    VALUE always_show_dot_files;
    VALUE case_sensitive;
    VALUE recurse;
    VALUE ignore_spaces;
    VALUE limit_option;
    VALUE last_needle;
    VALUE needle;
    VALUE never_show_dot_files;
    VALUE new_paths_object_id;
    VALUE options;
    VALUE paths;
    VALUE paths_object_id;
    VALUE results;
    VALUE scanner;
    VALUE sort_option;
    VALUE threads_option;
    VALUE wrapped_matches;

    // Process arguments: 1 mandatory, 1 optional.
    if (rb_scan_args(argc, argv, "11", &needle, &options) == 1) {
        options = Qnil;
    }
    if (NIL_P(needle)) {
        rb_raise(rb_eArgError, "nil needle");
    }

    // Check optional options hash for overrides.
    case_sensitive = CommandT_option_from_hash("case_sensitive", options);
    limit_option = CommandT_option_from_hash("limit", options);
    threads_option = CommandT_option_from_hash("threads", options);
    sort_option = CommandT_option_from_hash("sort", options);
    ignore_spaces = CommandT_option_from_hash("ignore_spaces", options);
    always_show_dot_files = rb_iv_get(self, "@always_show_dot_files");
    never_show_dot_files = rb_iv_get(self, "@never_show_dot_files");
    recurse = CommandT_option_from_hash("recurse", options);

    limit = NIL_P(limit_option) ? 15 : NUM2LONG(limit_option);
    sort = NIL_P(sort_option) || sort_option == Qtrue;
    use_heap = limit && sort;
    heap_matches_count = 0;

    needle = StringValue(needle);
    if (case_sensitive != Qtrue) {
        needle = rb_funcall(needle, rb_intern("downcase"), 0);
    }

    if (ignore_spaces == Qtrue) {
        needle = rb_funcall(needle, rb_intern("delete"), 1, rb_str_new2(" "));
    }

    // Get unsorted matches.
    scanner = rb_iv_get(self, "@scanner");
    paths = rb_funcall(scanner, rb_intern("paths"), 0);
    path_count = RARRAY_LEN(paths);

    // Cached C data, not visible to Ruby layer.
    paths_object_id = rb_ivar_get(self, rb_intern("paths_object_id"));
    new_paths_object_id = rb_funcall(paths, rb_intern("object_id"), 0);
    rb_ivar_set(self, rb_intern("paths_object_id"), new_paths_object_id);
    last_needle = rb_ivar_get(self, rb_intern("last_needle"));
    if (
        NIL_P(paths_object_id) ||
        rb_equal(new_paths_object_id, paths_object_id) != Qtrue
    ) {
        // `paths` changed, need to replace matches array.
        paths_object_id = new_paths_object_id;
        matches = malloc(path_count * sizeof(match_t));
        if (!matches) {
            rb_raise(rb_eNoMemError, "memory allocation failed");
        }
        wrapped_matches = Data_Wrap_Struct(
            rb_cObject,
            0,
            free,
            matches
        );
        rb_ivar_set(self, rb_intern("matches"), wrapped_matches);
        last_needle = Qnil;
    } else {
        // Get existing array.
        Data_Get_Struct(
            rb_ivar_get(self, rb_intern("matches")),
            match_t,
            matches
        );

        // Will compare against previously computed haystack bitmasks.
        needle_bitmask = calculate_bitmask(needle);

        // Check whether current search extends previous search; if so, we can
        // skip all the non-matches from last time without looking at them.
        if (rb_funcall(needle, rb_intern("start_with?"), 1, last_needle) != Qtrue) {
            last_needle = Qnil;
        }
    }

    thread_count = NIL_P(threads_option) ? 1 : NUM2LONG(threads_option);
    if (use_heap) {
        heap_matches = malloc(thread_count * limit * sizeof(match_t));
        if (!heap_matches) {
            rb_raise(rb_eNoMemError, "memory allocation failed");
        }
    }

#ifdef HAVE_PTHREAD_H
#define THREAD_THRESHOLD 1000 /* avoid the overhead of threading when search space is small */
    if (path_count < THREAD_THRESHOLD) {
        thread_count = 1;
    }
    threads = malloc(sizeof(pthread_t) * thread_count);
    if (!threads)
        rb_raise(rb_eNoMemError, "memory allocation failed");
#endif

    thread_args = malloc(sizeof(thread_args_t) * thread_count);
    if (!thread_args)
        rb_raise(rb_eNoMemError, "memory allocation failed");
    for (i = 0; i < thread_count; i++) {
        thread_args[i].thread_count = thread_count;
        thread_args[i].thread_index = i;
        thread_args[i].case_sensitive = case_sensitive == Qtrue;
        thread_args[i].matches = matches;
        thread_args[i].limit = use_heap ? limit : 0;
        thread_args[i].path_count = path_count;
        thread_args[i].haystacks = paths;
        thread_args[i].needle = needle;
        thread_args[i].last_needle = last_needle;
        thread_args[i].always_show_dot_files = always_show_dot_files;
        thread_args[i].never_show_dot_files = never_show_dot_files;
        thread_args[i].recurse = recurse;
        thread_args[i].needle_bitmask = needle_bitmask;

#ifdef HAVE_PTHREAD_H
        if (i == thread_count - 1) {
#endif
            // For the last "worker", we'll just use the main thread.
            heap = match_thread(&thread_args[i]);
            if (heap) {
                for (j = 0; j < heap->count; j++) {
                    heap_matches[heap_matches_count++] = *(match_t *)heap->entries[j];
                }
                heap_free(heap);
            }
#ifdef HAVE_PTHREAD_H
        } else {
            err = pthread_create(&threads[i], NULL, match_thread, (void *)&thread_args[i]);
            if (err != 0) {
                rb_raise(rb_eSystemCallError, "pthread_create() failure (%d)", (int)err);
            }
        }
#endif
    }

#ifdef HAVE_PTHREAD_H
    for (i = 0; i < thread_count - 1; i++) {
        err = pthread_join(threads[i], (void **)&heap);
        if (err != 0) {
            rb_raise(rb_eSystemCallError, "pthread_join() failure (%d)", (int)err);
        }
        if (heap) {
            for (j = 0; j < heap->count; j++) {
                heap_matches[heap_matches_count++] = *(match_t *)heap->entries[j];
            }
            heap_free(heap);
        }
    }
    free(threads);
#endif

    if (sort) {
        if (
            RSTRING_LEN(needle) == 0 ||
            (RSTRING_LEN(needle) == 1 && RSTRING_PTR(needle)[0] == '.')
        ) {
            // Alphabetic order if search string is only "" or "."
            // TODO: make those semantics fully apply to heap case as well
            // (they don't because the heap itself calls cmp_score, which means
            // that the items which stay in the top [limit] may (will) be
            // different).
            qsort(
                use_heap ? heap_matches : matches,
                use_heap ? heap_matches_count : path_count,
                sizeof(match_t),
                cmp_alpha
            );
        } else {
            qsort(
                use_heap ? heap_matches : matches,
                use_heap ? heap_matches_count : path_count,
                sizeof(match_t),
                cmp_score
            );
        }
    }

    results = rb_ary_new();
    if (limit == 0) {
        limit = path_count;
    }
    for (
        i = 0;
        i < (use_heap ? heap_matches_count : path_count) && limit > 0;
        i++
    ) {
        if ((use_heap ? heap_matches : matches)[i].score > 0.0) {
            rb_funcall(
                results,
                rb_intern("push"),
                1,
                (use_heap ? heap_matches : matches)[i].path
            );
            limit--;
        }
    }

    if (use_heap) {
        free(heap_matches);
    }

    // Save this state to potentially speed subsequent searches.
    rb_ivar_set(self, rb_intern("last_needle"), needle);
    return results;
}
