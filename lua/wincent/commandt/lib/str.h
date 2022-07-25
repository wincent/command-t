/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

/**
 * @file
 *
 * String representation with precomputed/cached length value.
 */

#ifndef STR_H
#define STR_H

#include <limits.h> /* for SSIZE_MAX */
#include <stddef.h> /* for size_t */
#include <sys/types.h> /* for ssize_t */

typedef struct {
    const char *contents;
    size_t length;

    /**
     * A capacity of -1 indicates an immutable (slab-allocated) string that
     * cannot be resized.
     */
    ssize_t capacity;
} str_t;

/**
 * Create new `str_t` struct and initialize it with a copy of the buffer of
 * `length` pointed to by `source`.
 */
str_t *str_new_copy(const char *source, size_t length);

/**
 * Initialize the provided `str_t` struct with the buffer of `length` pointed to
 * by `source`. The buffer is _not_ copied. A string initialized in this way is
 * flagged as belonging to a "slab" allocation by setting the `capacity` field
 * to -1.
 *
 * The use case here is to create cheap `str_t` wrappers around a slab of memory
 * from an external source (like a Watchman payload, or the output of a `git
 * ls-files` invocation) without having to make many small allocations and
 * copies.  The caller should allocate memory for all of the necessary `str_t`
 * structs in bulk, and when done, free the bulk storage and the external source
 * buffer (in this case, it need not even call `str_free()` on the individual
 * strings; it will be a no-op anyway).
 */
void str_init(str_t *str, const char *source, size_t length);

/**
 * Similar to `str_init()`, but _does_ copy the string. Not intended for use
 * with "slab" allocations.
 */
void str_init_copy(str_t *str, const char *source, size_t length);

/**
 * For debugging. Creates a new, empty str.
 *
 * @internal
 */
str_t *str_new(void);

/**
 * For debugging. Appends `length` bytes of `source` to `str`.
 *
 * @internal
 */
void str_append(str_t *str, const char *source, size_t length);

/**
 * For debugging. Appends `other` to `str`.
 *
 * @internal
 */
void str_append_str(str_t *str, str_t *other);

/**
 * Frees memory associated with `str`.
 */
void str_free(str_t *str);

/**
 * Returns a C string by copying the contents of `str`.
 *
 * Caller is responsible for `free()`-ing the returned string.
 */
const char *str_c_string(str_t *str);

#endif
