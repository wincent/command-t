// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <assert.h>
#include <ctype.h>
#include <stdlib.h>  /* for qsort() */
#include <string.h>  /* for strncmp() */

#include "match.h"
#include "matcher.h"
#include "heap.h"
#include "ext.h"
#include "scanner.h"
#include "ruby_compat.h"

// order matters; we want this to be evaluated only after ruby.h
#ifdef HAVE_PTHREAD_H
#include <pthread.h> /* for pthread_create, pthread_join etc */
#endif

static int cmp_path(const paths_t *a, const paths_t *b) {
    if (a->length > b->length) return cmp_path(a, b->parent);
    if (a->length < b->length) return cmp_path(a->parent, b);

    if (a->parent != b->parent) return cmp_path(a->parent, b->parent);

    size_t min_len = a->path_len < b->path_len? a->path_len : b->path_len;
    int r = strncmp(a->path, b->path, min_len);
    if (r) return r;
    return a->path_len - b->path_len;
}

// Comparison function for use with qsort.
int cmp_alpha(const void *a, const void *b)
{
    match_t *a_match = (match_t *)a;
    match_t *b_match = (match_t *)b;

    paths_t *a_path = a_match->path;
    paths_t *b_path = b_match->path;

    if (!a_path->parent) return -1;
    if (!b_path->parent) return 1;

    return cmp_path(a_path, b_path);
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
    const char *needle;
    uint32_t *needle_mask;
    size_t needle_len;
    size_t haystack_len;
} progress_t;

typedef struct {
    progress_t progress;
    long case_sensitive;
    paths_t *paths;
    size_t skip;
    size_t scan;
    long limit;
    match_t *matches;
    VALUE needle;
    int always_show_dot_files;
    int never_show_dot_files;
    VALUE recurse;

    heap_t *heap;
    char buf[PATHS_MAX_LEN];
} thread_args_t;

/** Update match progress.
 *
 * Advance the match progress based on the passed segment. If
 * progress->needle_len is zero when this function returns the current path and
 * all subpaths "match". However note that subpaths may be hidden.
 *
 * @return true if any subpath could match.
 */
static int continue_match(thread_args_t *args, progress_t *progress, paths_t *path)
{
    if (*progress->needle_mask & ~path->contained_mask)
        return 0;

    for (size_t i = 0; i < path->path_len; ++i) {
        char c = path->path[i];

        // Hidden file?
        if (c == '.' && (
            progress->haystack_len == 0 ||
            args->buf[progress->haystack_len - 1] == '/')) {
            if (args->never_show_dot_files)
                return 0;
            if (progress->needle[0] != '.' && !args->always_show_dot_files)
                return 0;
        }

        // Build up the path in the buffer.
        args->buf[progress->haystack_len++] = c;

        // Update match progress.
        if (progress->needle_len) {
            if (!args->case_sensitive) c = tolower(c);

            if (c == progress->needle[0]) {
                progress->needle++;
                progress->needle_len--;
                progress->needle_mask++;

                if (*progress->needle_mask & ~path->contained_mask)
                    return 0;
            }
        }
    }

    return 1;
}

void do_match(thread_args_t *args, paths_t *paths, progress_t progress) {
    if (!continue_match(args, &progress, paths)) {
        if (args->skip > paths->length) args->skip -= paths->length;
        else {
            size_t extra = paths->length - args->skip;
            if (extra < args->scan) args->scan -= extra;
            else args->scan = 0;
        }
        return;
    }

    if (!args->skip && paths->leaf && !progress.needle_len) {
       match_t new_match = {
            .path = paths,
            .score = calculate_match(
                args->buf,
                progress.haystack_len,
                args->needle,
                args->case_sensitive,
                args->recurse),
        };

        if (args->heap && args->heap->count == args->limit) {
            // Note: We can just compare the score because we are iterating in
            // alphabetical order so earlier items are preferred for equal score.
            if (new_match.score > ((match_t*)HEAP_PEEK(args->heap))->score) {
                match_t *buf = heap_extract(args->heap);
                *buf = new_match;
                heap_insert(args->heap, buf);
            }
        } else {
            *args->matches = new_match;
            if (args->heap) heap_insert(args->heap, args->matches);

            args->matches++;
        }
    }
    if (paths->leaf && !args->skip && args->scan) if (!--args->scan) return;
    if (paths->leaf && args->skip) args->skip -= 1;

    for (size_t i = 0; i < paths->subpaths_len; i++) {
        paths_t *next = paths->subpaths[i];
        if (args->skip >= next->length) {
            args->skip -= next->length;
            continue;
        }
        do_match(args, next, progress);
        if (!args->scan) return;
    }
}

void *match_thread(void *thread_args)
{
    thread_args_t *args = (thread_args_t *)thread_args;

    match_t *orig_matches = args->matches;

    if (args->limit) {
        args->heap = heap_new(args->limit, cmp_score);
    }

    do_match(args, args->paths, args->progress);

    size_t matches;
    if (args->heap) {
        matches = args->heap->count;
    } else {
        matches = args->matches - orig_matches;
    }

    heap_free(args->heap);

    return (void*)matches;
}

VALUE CommandTMatcher_sorted_matches_for(int argc, VALUE *argv, VALUE self)
{
    size_t i, limit, thread_count, err;
    int sort;
    size_t matches_len = 0;
    paths_t *paths;
    VALUE always_show_dot_files;
    VALUE case_sensitive;
    VALUE recurse;
    VALUE ignore_spaces;
    VALUE limit_option;
    VALUE needle;
    VALUE never_show_dot_files;
    VALUE options;
    VALUE paths_obj;
    VALUE results;
    VALUE scanner;
    VALUE sort_option;
    VALUE threads_option;

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

    needle = StringValue(needle);
    if (case_sensitive != Qtrue) {
        needle = rb_funcall(needle, rb_intern("downcase"), 0);
    }

    if (ignore_spaces == Qtrue) {
        needle = rb_funcall(needle, rb_intern("delete"), 1, rb_str_new2(" "));
    }

    const char *needle_str = RSTRING_PTR(needle);
    size_t needle_len = RSTRING_LEN(needle);

    uint32_t needle_masks[needle_len + 1];
    i = needle_len;
    needle_masks[i] = 0;
    while (i--) {
        needle_masks[i] = needle_masks[i+1] | hash_char(needle_str[i]);
    }

    // Get unsorted matches.
    scanner = rb_iv_get(self, "@scanner");
    paths_obj = rb_funcall(scanner, rb_intern("c_paths"), 0);
    paths = CommandTPaths_get_paths(paths_obj);
    if (paths == NULL) {
        rb_raise(rb_eArgError, "null matches");
    }

    if (!limit) limit = paths->length;

    size_t handled_paths = 0;

#ifdef HAVE_PTHREAD_H
    thread_count = NIL_P(threads_option) ? 0 : NUM2LONG(threads_option);
    size_t paths_per_thread = 10000;
    if (thread_count) {
        if (paths->length / thread_count < paths_per_thread) {
            thread_count = paths->length / paths_per_thread;
        } else {
            paths_per_thread = paths->length / thread_count;
        }
    }

    pthread_t threads[thread_count];
    match_t matches[limit * (thread_count + 1)];
    thread_args_t thread_args[thread_count];
    for (size_t i = 0; i < thread_count; ++i) {
        thread_args[i] = (thread_args_t){
            .progress = (progress_t){
                .needle = needle_str,
                .needle_len = needle_len,
                .needle_mask = needle_masks,
            },
            .case_sensitive = case_sensitive == Qtrue,
            .paths = paths,
            .matches = matches + limit*i,
            .limit = limit,
            .needle = needle,
            .always_show_dot_files = always_show_dot_files == Qtrue,
            .never_show_dot_files = never_show_dot_files == Qtrue,
            .recurse = recurse,
            .skip = handled_paths,
            .scan = paths_per_thread,
        };
        handled_paths += paths_per_thread;

        err = pthread_create(&threads[i], NULL, match_thread, (void *)&thread_args[i]);
        if (err != 0) {
            rb_raise(rb_eSystemCallError, "pthread_create() failure (%d)", (int)err);
        }
    }
#endif

    thread_args_t main_thread_arg = {
        .progress = (progress_t){
            .needle = needle_str,
            .needle_len = needle_len,
            .needle_mask = needle_masks,
        },
        .case_sensitive = case_sensitive == Qtrue,
        .paths = paths,
        .matches = matches + limit*thread_count,
        .limit = limit,
        .needle = needle,
        .always_show_dot_files = always_show_dot_files == Qtrue,
        .never_show_dot_files = never_show_dot_files == Qtrue,
        .recurse = recurse,
        .skip = handled_paths,
        .scan = SIZE_MAX,
    };
    size_t main_matches = (size_t)match_thread(&main_thread_arg);

#ifdef HAVE_PTHREAD_H
    for (i = 0; i < thread_count; i++) {
        size_t match_count;
        err = pthread_join(threads[i], (void *)&match_count);
        if (err != 0) {
            rb_raise(rb_eSystemCallError, "pthread_join() failure (%d)", (int)err);
        }
        memmove(
            matches + matches_len, matches + limit*i,
            match_count * sizeof(match_t));
        matches_len += match_count;
    }
    memmove(
        matches + matches_len, matches + limit*thread_count,
        main_matches * sizeof(match_t));
#endif
    matches_len += main_matches;

    if (sort) {
        qsort(matches, matches_len, sizeof(match_t), cmp_score);
    }

    results = rb_ary_new();
    if (matches_len > limit) matches_len = limit;
    for (i = 0; i < matches_len; i++) {
        VALUE path = paths_to_s(matches[i].path);
        rb_funcall(results, rb_intern("push"), 1, path);
    }
    return results;
}
