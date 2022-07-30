/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef FIND_H
#define FIND_H

#include <stddef.h> /* for size_t */

#include "commandt.h" /* for scanner_t */
#include "str.h" /* for str_t */

typedef struct {
    unsigned count;
    str_t *files;

    /**
     * NULL on success, a description of the error otherwise.
     */
    const char *error;

    /**
     * @internal
     *
     * Book-keeping needed for call to `munmap()`.
     */
    size_t files_size;

    /**
     * @internal
     *
     * Book-keeping detail, needed for call to `munmap()`.
     */
    char *buffer;

    /**
     * @internal
     *
     * Book-keeping detail, needed for call to `munmap()`.
     */
    size_t buffer_size;
} find_result_t;

find_result_t *commandt_find(const char *directory);
void commandt_find_result_free(find_result_t *result);

/**
 * Wrapper that calls `commandt_find()` with `directory` to obtain a `find_result_t`.
 * It uses the contents of the `find_result_t` to create a new `scanner_t`.  The
 * new scanner takes ownership of the resources, which means you should call
 * `scanner_free()` on it.
 */
scanner_t *commandt_file_scanner(const char *directory);

#endif
