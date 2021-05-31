// Copyright 2021-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <stdlib.h> /* for free(), NULL */

#include "scanner.h"
#include "xmalloc.h"

// TODO: make this capable of producing asynchronously.

/**
 * Returns a new scanner_t structure, or NULL on failure.
 */
scanner_t *scanner_new() {
    scanner_t *scanner = xmalloc(sizeof(scanner_t));

    long count = 1; // TODO: derive this from params

    scanner->candidates = xmalloc(count * sizeof(void *));
    scanner->count = count;
    scanner->version = 0;

    return scanner;
}

/**
 * Frees a previously created scanner_t structure.
 */
void scanner_free(scanner_t *scanner) {
    free(scanner->candidates);
    free(scanner);
}
