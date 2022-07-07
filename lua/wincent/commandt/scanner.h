/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef SCANNER_H
#define SCANNER_H

#include <stddef.h> /* for size_t */

#include "commandt.h" /* for scanner_t */
#include "str.h"

/**
 * Create a new `scanner_t` struct initialized with `candidates`.
 *
 * Copies are made of `candidates`. The caller should call `scanner_free()` when
 * done.
 */
scanner_t *scanner_new_copy(const char **candidates, size_t count);

/**
 * Create a new `scanner_t` struct initialized with `capacity`. If `capacity` is
 * 0, the default capacity is used.
 */
scanner_t *scanner_new(size_t capacity);

/**
 * For debugging, a human-readable string representation of the scanner.
 *
 * Caller should call `str_free()` on the returned string.
 */
str_t *scanner_dump(scanner_t *scanner);

void scanner_push_str(scanner_t *scanner, str_t **candidates, size_t count);

/**
 * Frees a previously created `scanner_t` structure.
 */
void scanner_free(scanner_t *scanner);

#endif
