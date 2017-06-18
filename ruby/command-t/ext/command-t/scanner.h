// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#ifndef SCANNER_H
#define SCANNER_H

#include <assert.h>

#include <ruby.h>

// The maximum length of any given path.
#define PATHS_MAX_LEN 4096

/** A set of paths.
 *
 * Internally they are stored as a tree with common prefixes shared. This
 * class also has some additional metadata to aid searching.
 */
typedef struct paths_t {
    struct paths_t *parent; /// The parent path or NULL if this is the root.
    size_t length; /// The number of contained paths.

    struct paths_t **subpaths; /// Child paths, sorted in ascending order.
    size_t subpaths_len; /// The number of children.

    char *path; /// The string representing this path component.
    uint32_t contained_mask; /// A bitmap of chars contained by this path.
    uint16_t path_len; /// The size of path in bytes.
    uint8_t leaf: 1; /// If set this path is in the set.

    /** If this object owns the string pointed to by path.
     *
     * Note that even if a string is owned it will be referenced by subpaths.
     */
    uint8_t owned_path: 1;
} paths_t;

static_assert(PATHS_MAX_LEN < UINT16_MAX, "paths_t.path_len is too small.");

extern VALUE CommandTPaths_from_array(VALUE, VALUE);
extern VALUE CommandTPaths_from_fd(VALUE, VALUE, VALUE, VALUE);
extern VALUE CommandTPaths_to_a(VALUE);

static inline uint32_t hash_char(char c) {
    if ('A' <= c && c <= 'Z')
        return 1 << (c - 'A');
    if ('a' <= c && c <= 'z')
        return 1 << (c - 'a');
    return 0;
}

static inline uint32_t contained_mask(const char *s, size_t len) {
    uint32_t r = 0;
    while (len--) {
        char c = *s++;
        r |= hash_char(c);
    }
    return r;
}

extern paths_t *CommandTPaths_get_paths(VALUE);

/** Print the given path.
 *
 * This prints the given path and all ancestors. Note that it does *not* print
 * any descendants.
 */
extern VALUE paths_to_s(const paths_t *);

/** Print a path to stderr.
 *
 * This prints a debugging representation of the passed path to stderr.
 */
extern void paths_dump(const paths_t *);

#endif
