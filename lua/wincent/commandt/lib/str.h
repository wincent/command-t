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

#include <stddef.h> /* for size_t */

typedef struct {
    const char *contents;
    size_t length;
    size_t capacity;
} str_t;

/**
 * Create new `str_t` struct and initialize it with a copy of the buffer of
 * `length` pointed to by `source`.
 */
str_t *str_new_copy(const char *source, size_t length);

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

#endif
