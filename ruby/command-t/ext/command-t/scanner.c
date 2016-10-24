// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <ruby.h>
#include <errno.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>
#include "scanner.h"
#include "match.h"
#include "matcher.h"
#include "ext.h"

typedef struct {
    VALUE source;
    size_t bufsize;
    matches_t matches;
} paths_t;

void mark_paths(paths_t *paths) {
    rb_gc_mark(paths->source);
}

void free_paths(paths_t *paths) {
    munmap(paths, paths->bufsize);
}

VALUE CommandTPaths_from_array(VALUE klass, VALUE source) {
    Check_Type(source, T_ARRAY);
    rb_obj_freeze(source);

    long len = RARRAY_LEN(source);
    long bufsize = sizeof(paths_t) + len * sizeof(match_t);
    paths_t *paths = mmap(NULL, bufsize,
                          PROT_READ | PROT_WRITE,
                          MAP_ANONYMOUS | MAP_PRIVATE | MAP_NORESERVE,
                          -1, 0);
    if (!paths) {
        rb_raise(rb_eNoMemError, "memory allocation failed");
    }
    paths->bufsize = bufsize;
    paths->matches.len = len;

    // The source must stay around as the backing string will be shared.
    paths->source = source;

    VALUE *source_array = RARRAY_PTR(source);
    while (len--) {
        rb_obj_freeze(source_array[len]);
        paths->matches.matches[len].path     = RSTRING_PTR(source_array[len]);
        paths->matches.matches[len].path_len = RSTRING_LEN(source_array[len]);
        paths->matches.matches[len].bitmask  = UNSET_BITMASK;
    }

    return Data_Wrap_Struct(klass, mark_paths, free_paths, paths);
}

VALUE CommandTPaths_from_fd(VALUE klass, VALUE source, VALUE term, VALUE opt) {
    int fd = NUM2LONG(source);

    if (RSTRING_LEN(term) != 1) {
        rb_raise(rb_eArgError, "Terminator must be one byte.");
    }
    unsigned char termc = RSTRING_PTR(term)[0];

    VALUE max_filesv = CommandT_option_from_hash("max_files", opt);
    long max_files = max_filesv != Qnil? NUM2LONG(max_filesv) : 300000000;

    VALUE dropv = CommandT_option_from_hash("drop", opt);
    long drop = dropv != Qnil? NUM2LONG(dropv) : 0;

    VALUE update = CommandT_option_from_hash("update", opt);
    long next_update = 0;

    VALUE filter = CommandT_option_from_hash("where", opt);

    ID call = rb_intern("call");
    VALUE scratch = Qnil;
    if (filter != Qnil) {
        scratch = rb_str_new(NULL, 0);
    }

    size_t buffer_len = 1099511627776; // 1TiB should be enough for anyone.
    size_t paths_len = sizeof(paths_t) + (max_files) * sizeof(match_t);
    size_t total_len = buffer_len + paths_len;

    paths_t *paths = mmap(NULL, total_len,
                          PROT_READ | PROT_WRITE,
                          MAP_ANONYMOUS | MAP_PRIVATE | MAP_NORESERVE,
                          -1, 0);
    char *buffer = (char*)paths + paths_len;
    if (paths == MAP_FAILED) {
        rb_sys_fail(strerror(errno));
    }
    paths->bufsize = total_len;
    paths->source = Qnil;

    char *start = buffer;
    char *end = buffer;
    ssize_t count = 1;
    long match_count = 0;
    while ((count = read(fd, end, 4096)) != 0) {
        if (count < 0) {
            munmap(paths, total_len);
            rb_raise(rb_eRuntimeError, "read returned error %s", strerror(errno));
        }

        end += count;

        while (start < end) {
            if (start[0] == termc) { start++; continue; }
            char *next_end = memchr(start, termc, end - start);
            if (!next_end) break;

            char *path = start + drop;
            int len = next_end - start - drop;

            start = next_end + 1;

            if (filter != Qnil) {
                rb_str_resize(scratch, len);
                memcpy(RSTRING_PTR(scratch), path, len);
                VALUE keep = rb_funcall(filter, call, 1, scratch);
                if (keep == Qnil || keep == Qfalse) {
                    continue;
                }
            }

            paths->matches.matches[match_count].path     = path;
            paths->matches.matches[match_count].path_len = len;
            paths->matches.matches[match_count].bitmask  = UNSET_BITMASK;
            match_count++;

            if (match_count >= max_files) {
                goto done; /* break two levels */
            }
            if (update != Qnil && match_count >= next_update) {
                next_update = NUM2LONG(rb_funcall(update, call, 1, LONG2NUM(match_count)));
            }
        }
    }
done:

    paths->matches.len = match_count;

    if (start < end) {
        rb_raise(rb_eRuntimeError, "Last byte of string must be the terminator.");
    }

    return Data_Wrap_Struct(klass, mark_paths, free_paths, paths);
}

VALUE CommandTPaths_to_a(VALUE self) {
    return matches_to_a(paths_get_matches(self));
}

matches_t *paths_get_matches(VALUE self) {
    paths_t *paths;
    Data_Get_Struct(self, paths_t, paths);
    return &paths->matches;
}

VALUE matches_to_a(matches_t *matches) {
    VALUE r = rb_ary_new();
    VALUE push = rb_intern("push");
    int i;
    for (i = 0; i < matches->len; i++) {
        rb_funcall(r, push, 1,
            rb_str_new(
                matches->matches[i].path,
                matches->matches[i].path_len));
    }
    return r;
}
