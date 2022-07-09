/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdio.h> /* for fprintf(), stderr */
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

scanner_t *scanner_new_copy(const char **candidates, unsigned count) {
    scanner_t *scanner = xmalloc(sizeof(scanner_t));
    scanner->candidates = xmalloc(count * sizeof(str_t *));
    for (unsigned i = 0; i < count; i++) {
        size_t length = strlen(candidates[i]);
        scanner->candidates[i] = str_new_copy(candidates[i], length);
    }
    scanner->count = count;
    scanner->capacity = count;
    scanner->clock = 0;
    return scanner;
}

scanner_t *scanner_new(unsigned capacity) {
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

static const char *NUL_BYTE = "\0";
static const char *L_BRACE = "{";
static const char *R_BRACE = "}";
static const char *COMMA = ",";
static const char *INDENT = "  ";
static const char *NEWLINE = "\n";

str_t *scanner_dump(scanner_t *scanner) {
    str_t *dump = str_new();
    str_append(dump, L_BRACE, 1);
    str_append(dump, NEWLINE, 1);
    for (unsigned i = 0; i < scanner->count; i++) {
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

void scanner_push_str(scanner_t *scanner, str_t **candidates, unsigned count) {
    if (scanner->capacity < scanner->count + count ) {
        unsigned new_capacity = scanner->count + count;
        scanner->candidates = xrealloc(scanner->candidates, new_capacity * sizeof(str_t *));
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

void commandt_print_scanner(scanner_t *scanner) {
    str_t *dump = scanner_dump(scanner);
    fprintf(stderr, "\n\n\n%s\n\n\n", dump->contents);
    str_free(dump);
}
