/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell. All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 */

/**
 * @file
 *
 * Immutable string representation with precomputed/cached length value.
 */

#ifndef STR_H
#define STR_H

#include <stddef.h> /* for size_t */

typedef struct {
    const char *contents;
    size_t length;
} str_t;

/**
 * Create new `str_t` struct and initialize it with a copy of the buffer of
 * `length` pointed to by `source`.
 */
str_t *str_new(const char *source, size_t length);

/**
 * Frees memory associated with `str`.
 */
void str_free(str_t *str);

#endif
