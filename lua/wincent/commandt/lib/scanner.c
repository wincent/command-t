/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "scanner.h"

#include <assert.h> /* for assert() */
#include <errno.h> /* for errno */
#include <signal.h> /* for SIGKILL, kill() */
#include <stddef.h> /* for NULL */
#include <stdio.h> /* for fprintf(), stderr */
#include <stdlib.h> /* for free() */
#include <string.h> /* for memchr(), strlen() */
#include <unistd.h> /* _exit(), close(), fork(), pipe(), read() */

#include "debug.h"
#include "str.h"
#include "xmalloc.h"
#include "xmap.h" /* for xmap(), xmunmap() */

// TODO: make this capable of producing asynchronously?

static long MAX_FILES = MAX_FILES_CONF;
static size_t buffer_size = MMAP_SLAB_SIZE_CONF;

scanner_t *scanner_new_copy(const char **candidates, unsigned count) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates_size = count * sizeof(str_t);
    if (count) {
        DEBUG_LOG("scanner_new_copy() -> xmap() %llu\n", scanner->candidates_size);
        scanner->candidates = xmap(scanner->candidates_size);
        for (unsigned i = 0; i < count; i++) {
            size_t length = strlen(candidates[i]);
            str_init_copy(&scanner->candidates[i], candidates[i], length);
        }
    }
    scanner->count = count;
    return scanner;
}

scanner_t *scanner_new_command(const char *command, unsigned drop, unsigned max_files) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates_size = sizeof(str_t) * MAX_FILES;
    DEBUG_LOG(
        "scanner_new_command() -> xmap() candidates %llu\n", scanner->candidates_size
    );
    scanner->candidates = xmap(scanner->candidates_size);
    scanner->buffer_size = buffer_size;
    DEBUG_LOG(
        "scanner_new_command() -> xmap() buffer %llu\n", scanner->buffer_size
    );
    scanner->buffer = xmap(scanner->buffer_size);

    // Index 0 = read end of pipe; index 1 = write end of pipe.
    int stdout_pipe[2];

    if (pipe(stdout_pipe) != 0) {
        DEBUG_LOG("scanner_new_command(): failed pipe() - %s\n", strerror(errno));
        goto out;
    }

    pid_t child_pid = fork();
    if (child_pid == -1) {
        DEBUG_LOG("scanner_new_command(): failed fork() - %s\n", strerror(errno));
        goto out;
    } else if (child_pid == 0) {
        // In child.
        DEBUG_LOG("scanner_new_command(): forked child\n");
        if (close(stdout_pipe[0]) != 0) {
            DEBUG_LOG(
                "scanner_new_command(): failed close() - %s\n", strerror(errno)
            );
        }
        if (dup2(stdout_pipe[1], 1) == -1) {
            DEBUG_LOG(
                "scanner_new_command(): failed dup2() - %s\n", strerror(errno)
            );
        }
        if (close(stdout_pipe[1]) != 0) {
            DEBUG_LOG(
                "scanner_new_command(): failed close() - %s\n", strerror(errno)
            );
        }

        // Fork a shell to mimic behavior of `popen()`.
        execl("/bin/sh", "sh", "-c", command, NULL);
        DEBUG_LOG("scanner_new_command(): failed execl() - %s\n", strerror(errno));
        _exit(1);
    }

    // In parent.
    DEBUG_LOG(
        "scanner_new_command(): parent forked child with PID %d\n", child_pid
    );
    int status = close(stdout_pipe[1]);
    if (status != 0) {
        DEBUG_LOG(
            "commandt_scanner_new_command(): failed close() - %s\n",
            strerror(errno)
        );
    }
    char *start = scanner->buffer;
    char *end = scanner->buffer;
    ssize_t read_count;
    while ((read_count = read(stdout_pipe[0], end, 4096)) != 0) {
        DEBUG_LOG("scanner_new_command(): read %d bytes\n", read_count);
        if (read_count < 0) {
            // A read error, but we may as well try and proceed gracefully.
            DEBUG_LOG(
                "scanner_new_command(): failed read() - %s\n", strerror(errno)
            );
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
                DEBUG_LOG(
                    "commandt_scanner_new_command(): not enough output to skip %u characters\n",
                    drop
                );
                goto bail;
            }
            start = next_end + 1;
            str_init(&scanner->candidates[scanner->count++], path, length);
            DEBUG_LOG(
                "commandt_scanner_new_command(): scanned %s\n",
                str_c_string(&scanner->candidates[scanner->count - 1])
            );

            if (max_files && scanner->count >= max_files) {
                DEBUG_LOG(
                    "commandt_scanner_new_command(): killing process %d because count %d\n",
                    child_pid,
                    scanner->count
                );
                if (kill(child_pid, SIGKILL)) {
                    DEBUG_LOG(
                        "commandt_scanner_new_command(): failed kill() - %s\n",
                        strerror(errno)
                    );
                }
                goto bail;
            }
        }
    }

bail:
    DEBUG_LOG("commandt_scanner_new_command(): waiting %d\n", child_pid);
    if (wait(&child_pid) == -1) {
        DEBUG_LOG(
            "commandt_scanner_new_command(): failed wait() - %s\n", strerror(errno)
        );
    }

out:
    DEBUG_LOG(
        "commandt_scanner_new_command(): returning scanner with count %d\n",
        scanner->count
    );
    return scanner;
}

scanner_t *scanner_new_str(str_t *candidates, unsigned count) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates = candidates;
    scanner->candidates_size = count * sizeof(str_t);
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
    for (unsigned i = 0; i < scanner->count; i++) {
        str_t str = scanner->candidates[i];
        if (str.capacity >= 0) {
            free((void *)str.contents);
        }
    }

    if (scanner->candidates) {
        xmunmap(scanner->candidates, scanner->candidates_size);
    }

    if (scanner->buffer) {
        xmunmap(scanner->buffer, scanner->buffer_size);
    }

    free(scanner);
}

void commandt_print_scanner(scanner_t *scanner) {
    str_t *dump = scanner_dump(scanner);
    fprintf(stderr, "\n\n\n%s\n\n\n", dump->contents);
    str_free(dump);
}
