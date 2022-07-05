/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell. All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdlib.h> /* for free() */

#include "scanner.h"
#include "xmalloc.h"

// TODO: make this capable of producing asynchronously?

/**
 * Default scanner capacity, suitable for most scanner types (eg. up to and
 * including help tags scanner).
 */
#define DEFAULT_CAPACITY (1 << 14)

scanner_t *scanner_new(size_t capacity) {
    scanner_t *scanner = xmalloc(sizeof(scanner_t));
    if (!capacity) {
        capacity = DEFAULT_CAPACITY;
    }
    scanner->candidates = xmalloc(capacity * sizeof(str_t *));
    scanner->count = 0;
    scanner->capacity = capacity;
    scanner->clock = 0;

    return scanner;
}

void scanner_free(scanner_t *scanner) {
    free(scanner->candidates);
    free(scanner);
}
