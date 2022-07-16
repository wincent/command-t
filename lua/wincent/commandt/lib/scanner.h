/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef SCANNER_H
#define SCANNER_H

#include "commandt.h" /* for scanner_t */
#include "str.h"

/**
 * Create a new `scanner_t` struct initialized with `candidates`.
 *
 * Copies are made of `candidates`. The caller should call `scanner_free()` when
 * done.
 */
scanner_t *scanner_new_copy(const char **candidates, unsigned count);

/**
 * Create a new `scanner_t` struct that will be populated by executing the
 * NUL-terminated `command` string.
 */
scanner_t *scanner_new_command(const char *command);

/**
 * Create a new `scanner_t` struct initialized with `candidates`.
 *
 * Copies of the candidates are _not_ made, as they are assumed to belong to an
 * `mmap()`-ed slab allocation and initialized with `str_init()`.
 */
scanner_t *scanner_new_str(str_t *candidates, unsigned count);

/**
 * For debugging, a human-readable string representation of the scanner.
 *
 * Caller should call `str_free()` on the returned string.
 *
 * @internal
 */
str_t *scanner_dump(scanner_t *scanner);

/**
 * Frees a previously created `scanner_t` structure.
 */
void scanner_free(scanner_t *scanner);

#endif
