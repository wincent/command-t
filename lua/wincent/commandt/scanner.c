/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdlib.h> /* for free() */
#include <string.h> /* for strlen() */

#include "scanner.h"
#include "xmalloc.h"

// TODO: make this capable of producing asynchronously?

/**
 * Default scanner capacity, suitable for most scanner types (eg. up to and
 * including help tags scanner).
 */
#define DEFAULT_CAPACITY (1 << 14)

scanner_t *scanner_new_copy(const char **candidates, size_t count) {
    scanner_t *scanner = xmalloc(sizeof(scanner_t));
    scanner->candidates = xcalloc(count, sizeof(str_t *));
    for (size_t i = 0; i < count; i++) {
        size_t length = strlen(candidates[i]);
        scanner->candidates[i] = str_new_copy(candidates[i], length);
    }
    scanner->count = count;
    scanner->capacity = count;
    scanner->clock = 0;
    return scanner;
}

scanner_t *scanner_new(size_t capacity) {
    scanner_t *scanner = xmalloc(sizeof(scanner_t));
    if (!capacity) {
        capacity = DEFAULT_CAPACITY;
    }
    scanner->candidates = xcalloc(capacity, sizeof(str_t *));
    scanner->count = 0;
    scanner->capacity = capacity;
    scanner->clock = 0;
    return scanner;
}

const char *NUL_BYTE = "\0";
const char *L_BRACE = "{";
const char *R_BRACE = "}";
const char *COMMA = ",";
const char *INDENT = "  ";
const char *NEWLINE = "\n";

str_t *scanner_dump(scanner_t *scanner) {
    str_t *dump = str_new();
    str_append(dump, L_BRACE, 1);
    str_append(dump, NEWLINE, 1);
    for (size_t i = 0; i < scanner->count; i++) {
        str_append(dump, INDENT, strlen(INDENT));
        str_append(
            dump,
            scanner->candidates[i]->contents,
            scanner->candidates[i]->length
        );
        str_append(dump, COMMA, 1);
        str_append(dump, NEWLINE, 1);
    }
    str_append(dump, R_BRACE, 1);
    str_append(dump, NUL_BYTE, 1);
    return dump;
}

void scanner_push_str(scanner_t *scanner, str_t **candidates, size_t count) {
    if (scanner->capacity < scanner->count + count ) {
        size_t new_capacity = scanner->count + count;
        scanner->candidates = xrealloc(scanner->candidates, new_capacity);
        scanner->capacity = new_capacity;
    }
    memcpy(
        scanner->candidates + sizeof(str_t *) * scanner->count,
        candidates,
        sizeof(str_t *) * count
    );
    scanner->count += count;
}

void scanner_free(scanner_t *scanner) {
    free(scanner->candidates);
    free(scanner);
}
