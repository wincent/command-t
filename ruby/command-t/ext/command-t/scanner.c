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

static void paths_free(paths_t *paths) {
    for (size_t i = 0; i < paths->subpaths_len; i++) {
        paths_free(paths->subpaths[i]);
    }
    if (paths->owned_path)
        free((void*)paths->path);
    free(paths);
}

/** Find the longest common prefix of two strings.
 *
 * @returns The length of the prefix.
 */
static size_t common_prefix(paths_t *a, const char *b, size_t bl) {
    size_t len = a->path_len > bl? bl : a->path_len;
    for (size_t i = 0; i < len; ++i) {
        if (a->path[i] != b[i]) return i;
    }
    return len;
}

/** Allocate a root path.
 */
static paths_t *paths_new_root(void) {
    paths_t *r = calloc(sizeof(paths_t), 1);
    if (!r) {
        rb_raise(rb_eNoMemError, "memory allocation failed");
    }
    return r;
}

static int is_power_of_2(size_t n) { return !(n & (n - 1)); }

/** Insert a path into a paths.
 *
 * It is the callers responsibility to ensure that the path should be put at the
 * specified location.
 *
 * @param paths Object to insert into.
 * @param i The index at which the path should reside after being inserted.
 * @param path The suffix of the path to be inserted.
 * @param len The length of path.
 */
static void _paths_insert_at(paths_t *paths, size_t i, const char *path, size_t len) {
    // The capacity of .subpaths is implied by .subpaths_len. Basically round up
    // .subpaths len to find the current capacity of 0, 2, 4, ...
    if (!paths->subpaths_len) paths->subpaths = malloc(2*sizeof(paths_t));
    else if (paths->subpaths_len < 2) {} // len = 1 -> capacity = 2
    else if (is_power_of_2(paths->subpaths_len)) {
        size_t capacity = paths->subpaths_len * 2;
        if (!capacity) capacity = 2;

        paths->subpaths = realloc(paths->subpaths, capacity*sizeof(paths_t*));
    }

    // Make room.
    memmove(paths->subpaths + i + 1, paths->subpaths + i,
        sizeof(paths_t*)*(paths->subpaths_len - i));
    paths->subpaths_len++;

    // Create and insert.
    paths_t *new = malloc(sizeof(paths_t));
    *new = (paths_t){
        .parent = paths,
        .length = 1,
        .path = strndup(path, len),
        .path_len = len,
        .owned_path = 1,
        .leaf = 1,
        .contained_mask = contained_mask(path, len),
    };
    paths->subpaths[i] = new;
}

/** Add a new path.
 *
 * @param paths The paths collection to insert into.
 * @param path The path to insert.
 * @param len The length (in bytes) of path.
 */
static void paths_push(paths_t *paths, const char *path, size_t len) {
    paths->length++;
    paths->contained_mask |= contained_mask(path, len);

    if (!len) {
        paths->leaf = 1;
        return;
    }

    // Iterate backwards because the common case is adding in order.
    for (size_t i = paths->subpaths_len; i--; ) {
        paths_t *subpath = paths->subpaths[i];

        if (subpath->path[0] == path[0]) {
            // First character matches, merge into this entry.

            size_t shared = common_prefix(subpath, path, len);
            if (shared == subpath->path_len) {
                // Goes inside the subpath.
                return paths_push(subpath, path + shared, len - shared);
            }

            paths_t *new = malloc(sizeof(paths_t));
            if (shared == len) {
                // Subpath should be inside this one.
                *new = (paths_t){
                    .parent = paths,
                    .length = subpath->length + 1,
                    .path = subpath->path,
                    .path_len = shared,
                    .contained_mask = subpath->contained_mask,
                    .leaf = 1,
                    .owned_path = subpath->owned_path,
                    .subpaths_len = 1,
                    .subpaths = malloc(2*sizeof(paths_t*)),
                };
                new->subpaths[0] = subpath;
            } else {
                // Create a fork
                uint32_t new_chars = contained_mask(path + shared, len - shared);
                *new = (paths_t){
                    .parent = paths,
                    .length = subpath->length + 1,
                    .path = subpath->path,
                    .path_len = shared,
                    .contained_mask = subpath->contained_mask | new_chars,
                    .owned_path = subpath->owned_path,
                    .subpaths_len = 2,
                    .subpaths = malloc(2*sizeof(paths_t*)),
                };
                paths_t *leaf = malloc(sizeof(paths_t));
                *leaf = (paths_t){
                    .parent = new,
                    .length = 1,
                    .path = strndup(path + shared, len - shared),
                    .path_len = len - shared,
                    .contained_mask = new_chars,
                    .leaf = 1,
                    .owned_path = 1,
                };
                if (subpath->path[shared] < path[shared]) {
                    new->subpaths[0] = subpath;
                    new->subpaths[1] = leaf;
                } else {
                    new->subpaths[0] = leaf;
                    new->subpaths[1] = subpath;
                }
            }
            paths->subpaths[i] = new;
            subpath->parent = new;
            subpath->path += shared;
            subpath->path_len -= shared;
            subpath->owned_path = 0;
            // Note: Ideally we would update subpath->contained_mask to not
            // include path[0..shared] but that would require a traversal of all
            // parents. This value is still "correct" just too conservative.
            return;
        } else if (subpath->path[0] < path[0]) {
            return _paths_insert_at(paths, i+1, path, len);
        }
    }

    // Before any subpath, so insert it in front.
    _paths_insert_at(paths, 0, path, len);
}

VALUE CommandTPaths_from_array(VALUE klass, VALUE source) {
    Check_Type(source, T_ARRAY);

    paths_t *paths = paths_new_root();

    long len = RARRAY_LEN(source);
    VALUE *source_array = RARRAY_PTR(source);
    for (long i = 0; i < len; ++i) {
        paths_push(paths, RSTRING_PTR(source_array[i]), RSTRING_LEN(source_array[i]));
    }

    return Data_Wrap_Struct(klass, NULL, paths_free, paths);
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

    paths_t *paths = paths_new_root();

    char buffer[PATHS_MAX_LEN];
    char *start = buffer;
    char *end = buffer;
    size_t count;
    long match_count = 0;
    while ((count = read(fd, end, sizeof(buffer) - (end - start))) != 0) {
        if (count <= 0) {
            paths_free(paths);
            rb_raise(rb_eRuntimeError, "read returned error %s", strerror(errno));
        }

        end += count;

        while (start < end) {
            if (start[0] == termc) { start++; continue; }
            char *next_end = memchr(start, termc, end - start);
            if (!next_end) break;

            char *path = start + drop;
            int len = next_end - start - drop;

            if (next_end-start < drop)
                rb_raise(rb_eRuntimeError,
                    "Terminator is less then drop away (%lu - %lu) '%.*s'.",
                    next_end-start, drop,
                    (int)(next_end-start), start);

            start = next_end + 1;

            if (filter != Qnil) {
                rb_str_resize(scratch, len);
                memcpy(RSTRING_PTR(scratch), path, len);
                VALUE keep = rb_funcall(filter, call, 1, scratch);
                if (keep == Qnil || keep == Qfalse) {
                    continue;
                }
            }

            paths_push(paths, path, len);

            if (paths->length >= (size_t)max_files) {
                goto done; /* break two levels */
            }
            if (update != Qnil && match_count >= next_update) {
                next_update = NUM2LONG(rb_funcall(update, call, 1, LONG2NUM(match_count)));
            }
        }

        size_t remaining = end - start;
        memmove(buffer, start, remaining);
        start = buffer;
        end = start + remaining;
    }
done:

    if (start < end) {
        rb_raise(rb_eRuntimeError, "Last byte of string must be the terminator.");
    }

    return Data_Wrap_Struct(klass, NULL, paths_free, paths);
}

paths_t *CommandTPaths_get_paths(VALUE self) {
    paths_t *paths;
    Data_Get_Struct(self, paths_t, paths);
    return paths;
}

static void paths_push_to_a(VALUE array, VALUE prefix, paths_t *paths) {
    size_t starting_len = RSTRING_LEN(prefix);

    rb_str_buf_cat(prefix, paths->path, paths->path_len);

    if (paths->leaf) {
        // Force a copy.
        VALUE leaf = rb_str_new(RSTRING_PTR(prefix), RSTRING_LEN(prefix));
        rb_ary_push(array, leaf);
    }

    for (size_t i = 0; i < paths->subpaths_len; ++i) {
        paths_push_to_a(array, prefix, paths->subpaths[i]);
    }

    rb_str_set_len(prefix, starting_len);
}

VALUE CommandTPaths_to_a(VALUE self) {
    VALUE r = rb_ary_new();
    VALUE path = rb_str_buf_new(0);
    paths_push_to_a(r, path, CommandTPaths_get_paths(self));
    return r;
}

static void indent(size_t depth) { while(depth--) fprintf(stderr, "| "); }

static void paths_dump_depth(const paths_t *paths, size_t depth) {
    indent(depth); fprintf(stderr, "PATHPATHPATH: %.*s\n", paths->path_len, paths->path);
    indent(depth); fprintf(stderr, "leaf: %u, owned: %u, mask: %#08x\n",
        paths->leaf, paths->owned_path, paths->contained_mask);
    indent(depth); fprintf(stderr, "subpaths: %ld, total: %ld\n", paths->subpaths_len, paths->length);
    for (size_t i = 0; i < paths->subpaths_len; ++i)
        paths_dump_depth(paths->subpaths[i], depth + 1);
}

void paths_dump(const paths_t *paths) {
    paths_dump_depth(paths, 0);
}

static VALUE paths_to_s_internal(const paths_t *paths, size_t len) {
    if (!paths->parent) {
        return rb_str_buf_new(len);
    }

    VALUE buf = paths_to_s_internal(paths->parent, len + paths->path_len);
    rb_str_buf_cat(buf, paths->path, paths->path_len);
    return buf;
}

VALUE paths_to_s(const paths_t *paths) {
    return paths_to_s_internal(paths, 0);
}
