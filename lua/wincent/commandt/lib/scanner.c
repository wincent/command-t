/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "scanner.h"

#include <assert.h> /* for assert() */
#include <signal.h> /* for SIGKILL, kill() */
#include <stddef.h> /* for NULL */
#include <stdio.h> /* for fprintf(), stderr */
#include <stdlib.h> /* for free() */
#include <string.h> /* for memchr(), strlen() */
#include <sys/wait.h> /* for wait() */
#include <unistd.h> /* _exit(), close(), fork(), pipe(), read() */

#include "str.h"
#include "xmalloc.h"
#include "xmap.h" /* for xmap(), xmunmap() */

// TODO: make this capable of producing asynchronously?

// Special `candidates_size`/`buffer_size` value to indicate that this scanner
// does not own its storage, but rather that the caller will be responsible for
// managing its lifecycle.
#define UNOWNED (-1)

static long MAX_FILES = MAX_FILES_CONF;
static size_t buffer_size = MMAP_SLAB_SIZE_CONF;

scanner_t *scanner_new_copy(const char **candidates, unsigned count) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates_size = count * sizeof(str_t);
    if (count) {
        scanner->candidates = xmap(scanner->candidates_size);
        for (unsigned i = 0; i < count; i++) {
            size_t length = strlen(candidates[i]);
            str_init_copy(&scanner->candidates[i], candidates[i], length);
        }
    }
    scanner->count = count;
    return scanner;
}

scanner_t *scanner_new_exec(const char *command, unsigned drop, unsigned max_files) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates_size = sizeof(str_t) * MAX_FILES;
    scanner->candidates = xmap(scanner->candidates_size);
    scanner->buffer_size = buffer_size;
    scanner->buffer = xmap(scanner->buffer_size);

    // Index 0 = read end of pipe; index 1 = write end of pipe.
    int stdout_pipe[2];

    if (pipe(stdout_pipe) != 0) {
        goto out;
    }

    pid_t child_pid = fork();
    if (child_pid == -1) {
        goto out;
    } else if (child_pid == 0) {
        // In child.
        if (close(stdout_pipe[0]) != 0) {
            goto bail_child;
        }
        if (dup2(stdout_pipe[1], 1) == -1) {
            goto bail_child;
        }
        if (close(stdout_pipe[1]) != 0) {
            goto bail_child;
        }

        // Fork a shell to mimic behavior of `popen()`.
        execl("/bin/sh", "sh", "-c", command, NULL);

bail_child:
        _exit(1);
    }

    // In parent.
    int status = close(stdout_pipe[1]);
    if (status != 0) {
        goto bail_parent;
    }
    char *start = scanner->buffer;
    char *end = scanner->buffer;
    ssize_t read_count;
    while ((read_count = read(stdout_pipe[0], end, 4096)) != 0) {
        if (read_count < 0) {
            // A read error, but we may as well try and proceed gracefully.
            break;
        }
        end += read_count;
        while (start < end) {
            if (start[0] == 0) { // TODO: terminator may not always be NUL (-z)
                start++;
                continue;
            }
            char *next_end = memchr(start, 0, end - start);
            if (!next_end) {
                break;
            }
            char *path = start + drop;
            int length = next_end - start - drop;
            if (length < 0) {
                goto bail_parent;
            }
            start = next_end + 1;
            str_init(&scanner->candidates[scanner->count++], path, length);

            if (max_files && scanner->count >= max_files) {
                kill(child_pid, SIGKILL);
                goto bail_parent;
            }
        }
    }

bail_parent:
    if (wait(&child_pid) == -1) {
        // Swallow the error.
    }

out:
    return scanner;
}

scanner_t *scanner_new_str(str_t *candidates, unsigned count) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates = candidates;

    // Hint to not `munmap()` memory in `scanner_free();
    scanner->candidates_size = UNOWNED;
    scanner->buffer_size = UNOWNED;

    scanner->count = count;
    return scanner;
}

scanner_t *scanner_new(
    unsigned count,
    str_t *candidates,
    size_t candidates_size,
    char *buffer,
    size_t buffer_size
) {
    assert(candidates);
    assert(buffer);
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->count = count;
    scanner->candidates = candidates;
    scanner->candidates_size = candidates_size;
    scanner->buffer = buffer;
    scanner->buffer_size = buffer_size;
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
            dump, scanner->candidates[i].contents, scanner->candidates[i].length
        );
        str_append(dump, COMMA, 1);
        str_append(dump, NEWLINE, 1);
    }
    str_append(dump, R_BRACE, 1);
    str_append(dump, NUL_BYTE, 1);
    return dump;
}

void scanner_free(scanner_t *scanner) {
    if (scanner->candidates && scanner->candidates_size != UNOWNED) {
        for (unsigned i = 0; i < scanner->count; i++) {
            str_t str = scanner->candidates[i];
            if (str.capacity >= 0) {
                free((void *)str.contents);
            }
        }

        xmunmap(scanner->candidates, scanner->candidates_size);
    }

    if (scanner->buffer && scanner->buffer_size != UNOWNED) {
        xmunmap(scanner->buffer, scanner->buffer_size);
    }

    free(scanner);
}

void commandt_print_scanner(scanner_t *scanner) {
    str_t *dump = scanner_dump(scanner);
    fprintf(stderr, "\n\n\n%s\n\n\n", dump->contents);
    str_free(dump);
}
