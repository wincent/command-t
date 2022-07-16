/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <assert.h> /* for assert() */
#include <stddef.h> /* for NULL */
#include <stdio.h> /* for fileno(), fprintf(), pclose(), popen(), stderr */
#include <stdlib.h> /* for free() */
#include <string.h> /* for memchr(), strlen() */
#include <sys/mman.h> /* for munmap() */
#include <unistd.h> /* read() */

#include "debug.h"
#include "scanner.h"
#include "xmalloc.h"
#include "xmap.h"

// TODO: make this capable of producing asynchronously?

// TODO make this configurable
static long MAX_FILES = 134217728; // 128 M candiates.

static size_t buffer_size = 137438953472; // 128 GB.

scanner_t *scanner_new_copy(const char **candidates, unsigned count) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates_size = count * sizeof(str_t);
    if (count) {
        DEBUG_LOG("xmap() %d\n", scanner->candidates_size);
        scanner->candidates = xmap(scanner->candidates_size);
        for (unsigned i = 0; i < count; i++) {
            size_t length = strlen(candidates[i]);
            str_init_copy(&scanner->candidates[i], candidates[i], length);
        }
    }
    scanner->count = count;
    return scanner;
}

scanner_t *scanner_new_command(const char *command) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates_size = sizeof(str_t) * MAX_FILES;
    scanner->candidates = xmap(scanner->candidates_size);
    scanner->buffer = xmap(buffer_size);

    FILE *file = popen(command, "r");
    if (!file) {
        // Rather than crashing the process, act like we got an empty result.
        goto out;
    }
    int fd = fileno(file);

    char *start = scanner->buffer;
    char *end = scanner->buffer;
    ssize_t read_count;
    while ((read_count = read(fd, end, 4096)) != 0) {
        if (read_count < 0) {
            // A read error, but we may as well try and proceed gracefully.
            break;
        }
        end += read_count;
        while (start < end) {
            if  (start[0] == 0) { // TODO: may not always be -z
                start++;
                continue;
            }
            char *next_end = memchr(start, 0, end - start);
            if (!next_end) {
                break;
            }
            char *path = start + 0; // drop;
            int length = next_end - start - 0; // drop
            start = next_end + 1;
            str_init(&scanner->candidates[scanner->count++], path, length);

            if (scanner->count >= MAX_FILES) {
                // TODO: make this real
            }
        }
    }

    int status = pclose(file);
    if (status == -1) {
        // Probably a `wait4()` call failed.
    } else if (status != 0) {
        // Command exited with non-zero status. Again we degrade.
    }

out:
    return scanner;
}

scanner_t *scanner_new_str(str_t *candidates, unsigned count) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates = candidates;
    scanner->count = count;
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
            scanner->candidates[i].contents,
            scanner->candidates[i].length
        );
        str_append(dump, COMMA, 1);
        str_append(dump, NEWLINE, 1);
    }
    str_append(dump, R_BRACE, 1);
    str_append(dump, NUL_BYTE, 1);
    return dump;
}

void scanner_free(scanner_t *scanner) {
    for (unsigned i = 0; i < scanner->count; i++) {
        str_t str = scanner->candidates[i];
        if (str.capacity >= 0) {
            free((void *)str.contents);
        }
    }

    if (scanner->candidates) {
        DEBUG_LOG("munmap() %d\n", scanner->candidates_size);
        assert(munmap(scanner->candidates, scanner->candidates_size) == 0);
    }

    if (scanner->buffer) {
        assert(munmap(scanner->buffer, scanner->buffer_size) == 0);
    }

    free(scanner);
}

void commandt_print_scanner(scanner_t *scanner) {
    str_t *dump = scanner_dump(scanner);
    fprintf(stderr, "\n\n\n%s\n\n\n", dump->contents);
    str_free(dump);
}
