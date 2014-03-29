// Copyright 2010-2014 Wincent Colaiuta. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice,
//    this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.

#include <stdlib.h>  /* for qsort() */
#include <string.h>  /* for strncmp() */
#include "matcher.h"
#include "match.h"
#include "ext.h"
#include "ruby_compat.h"

// order matters; we want this to be evaluated only after ruby.h
#ifdef HAVE_PTHREAD_H
#include <pthread.h> /* for pthread_create, pthread_join etc */
#endif

// comparison function for use with qsort
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
            order = 1; // shorter string (b) wins
    } else if (a_len < b_len) {
        order = strncmp(a_p, b_p, a_len);
        if (order == 0)
            order = -1; // shorter string (a) wins
    } else {
        order = strncmp(a_p, b_p, a_len);
    }

    return order;
}

// comparison function for use with qsort
int cmp_score(const void *a, const void *b)
{
    match_t a_match = *(match_t *)a;
    match_t b_match = *(match_t *)b;

    if (a_match.score > b_match.score)
        return -1; // a scores higher, a should appear sooner
    else if (a_match.score < b_match.score)
        return 1;  // b scores higher, a should appear later
    else
        return cmp_alpha(a, b);
}

VALUE CommandTMatcher_initialize(int argc, VALUE *argv, VALUE self)
{
    VALUE always_show_dot_files;
    VALUE never_show_dot_files;
    VALUE options;
    VALUE scanner;

    // process arguments: 1 mandatory, 1 optional
    if (rb_scan_args(argc, argv, "11", &scanner, &options) == 1)
        options = Qnil;
    if (NIL_P(scanner))
        rb_raise(rb_eArgError, "nil scanner");

    rb_iv_set(self, "@scanner", scanner);

    // check optional options hash for overrides
    always_show_dot_files = CommandT_option_from_hash("always_show_dot_files", options);
    never_show_dot_files = CommandT_option_from_hash("never_show_dot_files", options);

    rb_iv_set(self, "@always_show_dot_files", always_show_dot_files);
    rb_iv_set(self, "@never_show_dot_files", never_show_dot_files);

    return Qnil;
}

typedef struct {
    int thread_count;
    int thread_index;
    match_t *matches;
    long path_count;
    VALUE paths;
    VALUE abbrev;
    VALUE always_show_dot_files;
    VALUE never_show_dot_files;
} thread_args_t;

void *match_thread(void *thread_args)
{
    long i;
    thread_args_t *args = (thread_args_t *)thread_args;
    for (i = args->thread_index; i < args->path_count; i += args->thread_count) {
        VALUE path = RARRAY_PTR(args->paths)[i];
        calculate_match(path,
                        args->abbrev,
                        args->always_show_dot_files,
                        args->never_show_dot_files,
                        &args->matches[i]);
    }

    return NULL;
}


VALUE CommandTMatcher_sorted_matches_for(int argc, VALUE *argv, VALUE self)
{
    long i, limit, path_count, thread_count;
#ifdef HAVE_PTHREAD_H
    long err;
#endif
    match_t *matches;
    thread_args_t *thread_args;
    VALUE abbrev;
    VALUE always_show_dot_files;
    VALUE limit_option;
    VALUE never_show_dot_files;
    VALUE options;
    VALUE paths;
    VALUE results;
    VALUE scanner;
    VALUE threads_option;

    // process arguments: 1 mandatory, 1 optional
    if (rb_scan_args(argc, argv, "11", &abbrev, &options) == 1)
        options = Qnil;
    if (NIL_P(abbrev))
        rb_raise(rb_eArgError, "nil abbrev");

    abbrev = StringValue(abbrev);
    abbrev = rb_funcall(abbrev, rb_intern("downcase"), 0);

    // check optional options has for overrides
    limit_option = CommandT_option_from_hash("limit", options);
    threads_option = CommandT_option_from_hash("threads", options);

    // get unsorted matches
    scanner = rb_iv_get(self, "@scanner");
    paths = rb_funcall(scanner, rb_intern("paths"), 0);
    always_show_dot_files = rb_iv_get(self, "@always_show_dot_files");
    never_show_dot_files = rb_iv_get(self, "@never_show_dot_files");

    path_count = RARRAY_LEN(paths);
    matches = malloc(path_count * sizeof(match_t));
    if (!matches)
        rb_raise(rb_eNoMemError, "memory allocation failed");

    thread_count = NIL_P(threads_option) ? 1 : NUM2LONG(threads_option);

#ifdef HAVE_PTHREAD_H
#define THREAD_THRESHOLD 1000 /* avoid the overhead of threading when search space is small */
    if (path_count < THREAD_THRESHOLD)
        thread_count = 1;
    pthread_t *threads = malloc(sizeof(pthread_t) * thread_count);
    if (!threads)
        rb_raise(rb_eNoMemError, "memory allocation failed");
#endif

    thread_args = malloc(sizeof(thread_args_t) * thread_count);
    if (!thread_args)
        rb_raise(rb_eNoMemError, "memory allocation failed");
    for (i = 0; i < thread_count; i++) {
        thread_args[i].thread_count = thread_count;
        thread_args[i].thread_index = i;
        thread_args[i].matches = matches;
        thread_args[i].path_count = path_count;
        thread_args[i].paths = paths;
        thread_args[i].abbrev = abbrev;
        thread_args[i].always_show_dot_files = always_show_dot_files;
        thread_args[i].never_show_dot_files = never_show_dot_files;

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

    if (RSTRING_LEN(abbrev) == 0 ||
        (RSTRING_LEN(abbrev) == 1 && RSTRING_PTR(abbrev)[0] == '.'))
        // alphabetic order if search string is only "" or "."
        qsort(matches, path_count, sizeof(match_t), cmp_alpha);
    else
        // for all other non-empty search strings, sort by score
        qsort(matches, path_count, sizeof(match_t), cmp_score);

    results = rb_ary_new();

    limit = NIL_P(limit_option) ? 0 : NUM2LONG(limit_option);
    if (limit == 0)
        limit = path_count;
    for (i = 0; i < path_count && limit > 0; i++) {
        if (matches[i].score > 0.0) {
            rb_funcall(results, rb_intern("push"), 1, matches[i].path);
            limit--;
        }
    }

    free(matches);
    return results;
}
