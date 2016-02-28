// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdlib.h>  /* for qsort() */
#include <string.h>  /* for strncmp() */
#include "match.h"
#include "matcher.h"
#include "ext.h"
#include "ruby_compat.h"

// order matters; we want this to be evaluated only after ruby.h
#ifdef HAVE_PTHREAD_H
#include <pthread.h> /* for pthread_create, pthread_join etc */
#endif

// Struct for representing an individual match.
typedef struct {
    VALUE   path;
    double  score;
} match_t;

// Comparison function for use with qsort.
int cmp_alpha(const void *a, const void *b)
{
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
int cmp_score(const void *a, const void *b)
{
    match_t a_match = *(match_t *)a;
    match_t b_match = *(match_t *)b;

    if (a_match.score > b_match.score)
        return -1; // a scores higher, a should appear sooner.
    else if (a_match.score < b_match.score)
        return 1;  // b scores higher, a should appear later.
    else
        return cmp_alpha(a, b);
}

VALUE CommandTMatcher_initialize(int argc, VALUE *argv, VALUE self)
{
    VALUE always_show_dot_files;
    VALUE never_show_dot_files;
    VALUE options;
    VALUE scanner;

    // Process arguments: 1 mandatory, 1 optional.
    if (rb_scan_args(argc, argv, "11", &scanner, &options) == 1)
        options = Qnil;
    if (NIL_P(scanner))
        rb_raise(rb_eArgError, "nil scanner");

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
    match_t *matches;
    long path_count;
    VALUE haystacks;
    VALUE needle;
    VALUE always_show_dot_files;
    VALUE never_show_dot_files;
    VALUE recurse;
    long needle_bitmask;
    long *haystack_bitmasks;
} thread_args_t;

void *match_thread(void *thread_args)
{
    long i;
    thread_args_t *args = (thread_args_t *)thread_args;
    for (i = args->thread_index; i < args->path_count; i += args->thread_count) {
        args->matches[i].path = RARRAY_PTR(args->haystacks)[i];
        args->matches[i].score = calculate_match(
                args->matches[i].path,
                args->needle,
                args->case_sensitive,
                args->always_show_dot_files,
                args->never_show_dot_files,
                args->recurse,
                args->needle_bitmask,
                &args->haystack_bitmasks[i]
        );
    }

    return NULL;
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
    long i, limit, path_count, thread_count;
#ifdef HAVE_PTHREAD_H
    long err;
    pthread_t *threads;
#endif
    long *bitmasks;
    long needle_bitmask;
    match_t *matches;
    thread_args_t *thread_args;
    VALUE always_show_dot_files;
    VALUE case_sensitive;
    VALUE recurse;
    VALUE ignore_spaces;
    VALUE limit_option;
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
    VALUE wrapped_bitmasks;
    VALUE wrapped_matches;

    // Process arguments: 1 mandatory, 1 optional.
    if (rb_scan_args(argc, argv, "11", &needle, &options) == 1)
        options = Qnil;
    if (NIL_P(needle))
        rb_raise(rb_eArgError, "nil needle");

    needle_bitmask = calculate_bitmask(needle);

    // Check optional options hash for overrides.
    case_sensitive = CommandT_option_from_hash("case_sensitive", options);
    limit_option = CommandT_option_from_hash("limit", options);
    threads_option = CommandT_option_from_hash("threads", options);
    sort_option = CommandT_option_from_hash("sort", options);
    ignore_spaces = CommandT_option_from_hash("ignore_spaces", options);
    always_show_dot_files = rb_iv_get(self, "@always_show_dot_files");
    never_show_dot_files = rb_iv_get(self, "@never_show_dot_files");
    recurse = CommandT_option_from_hash("recurse", options);

    needle = StringValue(needle);
    if (case_sensitive != Qtrue)
        needle = rb_funcall(needle, rb_intern("downcase"), 0);

    if (ignore_spaces == Qtrue)
        needle = rb_funcall(needle, rb_intern("delete"), 1, rb_str_new2(" "));

    // Get unsorted matches.
    scanner = rb_iv_get(self, "@scanner");
    paths = rb_funcall(scanner, rb_intern("paths"), 0);
    path_count = RARRAY_LEN(paths);

    // Cached C data, not visible to Ruby layer.
    paths_object_id = rb_ivar_get(self, rb_intern("paths_object_id"));
    new_paths_object_id = rb_funcall(paths, rb_intern("object_id"), 0);
    rb_ivar_set(self, rb_intern("paths_object_id"), new_paths_object_id);
    if (
        NIL_P(paths_object_id) ||
        NUM2LONG(new_paths_object_id) != NUM2LONG(paths_object_id)
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
        bitmasks = calloc(path_count, sizeof(long));
        if (!bitmasks) {
            rb_raise(rb_eNoMemError, "memory allocation failed");
        }
        wrapped_bitmasks = Data_Wrap_Struct(
            rb_cObject,
            0,
            free,
            bitmasks
        );
        rb_ivar_set(self, rb_intern("bitmasks"), wrapped_bitmasks);
    } else {
        // Get existing arrays.
        Data_Get_Struct(
            rb_ivar_get(self, rb_intern("matches")),
            match_t,
            matches
        );
        Data_Get_Struct(
            rb_ivar_get(self, rb_intern("bitmasks")),
            long,
            bitmasks
        );
    }

    thread_count = NIL_P(threads_option) ? 1 : NUM2LONG(threads_option);

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
        thread_args[i].path_count = path_count;
        thread_args[i].haystacks = paths;
        thread_args[i].needle = needle;
        thread_args[i].always_show_dot_files = always_show_dot_files;
        thread_args[i].never_show_dot_files = never_show_dot_files;
        thread_args[i].recurse = recurse;
        thread_args[i].needle_bitmask = needle_bitmask;
        thread_args[i].haystack_bitmasks = bitmasks;

#ifdef HAVE_PTHREAD_H
        if (i == thread_count - 1) {
#endif
            // for the last "worker", we'll just use the main thread
            (void)match_thread(&thread_args[i]);
#ifdef HAVE_PTHREAD_H
        } else {
            err = pthread_create(&threads[i], NULL, match_thread, (void *)&thread_args[i]);
            if (err != 0)
                rb_raise(rb_eSystemCallError, "pthread_create() failure (%d)", (int)err);
        }
#endif
    }

#ifdef HAVE_PTHREAD_H
    for (i = 0; i < thread_count - 1; i++) {
        err = pthread_join(threads[i], NULL);
        if (err != 0)
            rb_raise(rb_eSystemCallError, "pthread_join() failure (%d)", (int)err);
    }
    free(threads);
#endif

    if (NIL_P(sort_option) || sort_option == Qtrue) {
        if (RSTRING_LEN(needle) == 0 ||
            (RSTRING_LEN(needle) == 1 && RSTRING_PTR(needle)[0] == '.'))
            // alphabetic order if search string is only "" or "."
            qsort(matches, path_count, sizeof(match_t), cmp_alpha);
        else
            // for all other non-empty search strings, sort by score
            qsort(matches, path_count, sizeof(match_t), cmp_score);
    }

    results = rb_ary_new();

    limit = NIL_P(limit_option) ? 15 : NUM2LONG(limit_option);
    if (limit == 0)
        limit = path_count;
    for (i = 0; i < path_count && limit > 0; i++) {
        if (matches[i].score > 0.0) {
            rb_funcall(results, rb_intern("push"), 1, matches[i].path);
            limit--;
        }
    }

    return results;
}
