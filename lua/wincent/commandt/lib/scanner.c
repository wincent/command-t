/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "scanner.h"

#include <assert.h> /* for assert() */
#include <pthread.h> /* for pthread_create(), pthread_join() */
#include <signal.h> /* for SIGKILL, kill() */
#include <stdbool.h> /* for bool */
#include <stddef.h> /* for NULL */
#include <stdlib.h> /* for free() */
#include <string.h> /* for memchr(), strlen() */
#include <sys/wait.h> /* for waitpid() */
#include <unistd.h> /* _exit(), close(), dup2(), fork(), pipe(), read(), setpgid() */

#include "str.h" /* for str_init(), str_init_copy() */
#include "xmalloc.h" /* for xcalloc(), xmalloc() */
#include "xmap.h" /* for xmap(), xmunmap() */

// Special `candidates_size`/`buffer_size` value to indicate that this scanner
// does not own its storage, but rather that the caller will be responsible for
// managing its lifecycle.
#define UNOWNED (-1)

// Drain up to a full pipe buffer in a single read();
// 64KB is the default on macOS and Linux.
#define READ_CHUNK (64 * 1024)

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
    scanner->capacity = count;
    return scanner;
}

// Result of a `scanner_tokenize()` call.
typedef enum {
    TOKENIZE_MORE, // Consumed all complete tokens; more bytes may follow.
    TOKENIZE_FULL, // Hit `max_files`; the caller should stop reading.
    TOKENIZE_ERROR, // Malformed input (a `drop` larger than the token).
} tokenize_result_t;

// Split complete NUL-terminated tokens out of `[*start, end)`, appending a
// zero-copy `str_t` for each into `scanner->candidates` at index `*count`.
// Advances `*start` past consumed tokens and updates `*count`. A trailing
// partial token (no NUL yet) is left in place for a subsequent call once more
// bytes have arrived.
static tokenize_result_t scanner_tokenize(
    scanner_t *scanner,
    unsigned drop,
    unsigned max_files,
    char **start,
    char *end,
    unsigned *count
) {
    char *s = *start;
    unsigned n = *count;
    unsigned capacity = scanner->candidates_size > 0
        ? (unsigned)((size_t)scanner->candidates_size / sizeof(str_t))
        : 0;
    tokenize_result_t result = TOKENIZE_MORE;
    while (s < end) {
        if (s[0] == 0) { // TODO: terminator may not always be NUL (-z)
            s++;
            continue;
        }
        char *next_end = memchr(s, 0, end - s);
        if (!next_end) {
            break; // Incomplete token; wait for more bytes.
        }
        char *path = s + drop;
        long length = (long)(next_end - s) - (long)drop;
        if (length < 0) {
            result = TOKENIZE_ERROR;
            break;
        }
        s = next_end + 1;
        str_init(&scanner->candidates[n++], path, (size_t)length);
        if ((max_files && n >= max_files) || (capacity && n >= capacity)) {
            result = TOKENIZE_FULL;
            break;
        }
    }
    *start = s;
    *count = n;
    return result;
}

// Fork a shell running `command` with its stdout connected to a pipe. On
// success returns the child PID and stores the read end of the pipe in
// `*read_fd`; on failure returns -1.
static pid_t spawn_command(const char *command, int *read_fd) {
    int stdout_pipe[2]; // Index 0 = read end; index 1 = write end.
    if (pipe(stdout_pipe) != 0) {
        return -1;
    }
    pid_t child_pid = fork();
    if (child_pid == -1) {
        close(stdout_pipe[0]);
        close(stdout_pipe[1]);
        return -1;
    } else if (child_pid == 0) {
        // In child. Put ourselves in a new process group so the parent can
        // signal the whole command tree at once. Killing just the shell would
        // orphan whatever it spawned (eg. `fd`), and that orphan keeps the pipe
        // open, stalling our reader until it finishes on its own.
        setpgid(0, 0);
        if (close(stdout_pipe[0]) != 0) {
            _exit(1);
        }
        if (dup2(stdout_pipe[1], 1) == -1) {
            _exit(1);
        }
        if (close(stdout_pipe[1]) != 0) {
            _exit(1);
        }
        // Fork a shell to mimic behavior of `popen()`.
        execl("/bin/sh", "sh", "-c", command, NULL);
        _exit(1);
    }
    // In parent. Mirror the child's setpgid() to close the race (whichever runs
    // first wins; the loser's call fails harmlessly).
    setpgid(child_pid, child_pid);
    close(stdout_pipe[1]);
    *read_fd = stdout_pipe[0];
    return child_pid;
}

scanner_t *scanner_new_exec(const char *command, unsigned drop, unsigned max_files) {
    // Retain the blocking entry point without a second scanning implementation.
    scanner_t *scanner = scanner_new_exec_async(command, drop, max_files);
    scanner_wait(scanner);
    scanner->kind = SCANNER_EAGER;
    scanner->capacity = scanner->count;
    return scanner;
}

// Background producer for `scanner_new_exec_async()`: blocking-read the child's
// stdout into the slab, tokenizing and publishing `count` as it goes.
static void *exec_producer(void *arg) {
    scanner_t *scanner = arg;
    char *start = scanner->buffer;
    char *end = scanner->buffer;
    char *buffer_end = scanner->buffer + scanner->buffer_size;
    unsigned count = 0;
    ssize_t read_count;
    while (end < buffer_end) {
        size_t want = (size_t)(buffer_end - end);
        if (want > READ_CHUNK) {
            want = READ_CHUNK;
        }
        read_count = read(scanner->fd, end, want);
        if (read_count <= 0) {
            break; // EOF or read error.
        }
        end += read_count;
        tokenize_result_t result = scanner_tokenize(
            scanner, scanner->drop, scanner->max_files, &start, end, &count
        );
        // Publish (release) so the matcher's acquire-load of `count` observes
        // fully-initialized candidates below the published value.
        __atomic_store_n(&scanner->count, count, __ATOMIC_RELEASE);
        if (result != TOKENIZE_MORE) {
            // Negative PID signals the whole process group (see spawn_command).
            kill(-scanner->pid, SIGKILL); // max_files reached or malformed input.
            break;
        }
    }
    __atomic_store_n(&scanner->count, count, __ATOMIC_RELEASE);
    if (end == buffer_end) {
        kill(-scanner->pid, SIGKILL);
    }
    // The child is reaped and `fd` closed by `scanner_stop()` on the main
    // thread; leaving the child unreaped here keeps its PID valid (never
    // reused) so `scanner_stop()`'s `kill()` cannot target another process.
    __atomic_store_n(&scanner->done, 1, __ATOMIC_RELEASE);
    return NULL;
}

scanner_t *scanner_new_exec_async(
    const char *command, unsigned drop, unsigned max_files
) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->kind = SCANNER_EXEC;
    scanner->fd = -1;
    scanner->pid = -1;
    scanner->drop = drop;
    scanner->max_files = max_files;
    scanner->candidates_size = sizeof(str_t) * MAX_FILES;
    scanner->candidates = xmap(scanner->candidates_size);
    scanner->capacity = MAX_FILES;
    scanner->buffer_size = buffer_size;
    scanner->buffer = xmap(scanner->buffer_size);

    int read_fd;
    pid_t child_pid = spawn_command(command, &read_fd);
    if (child_pid == -1) {
        __atomic_store_n(&scanner->done, 1, __ATOMIC_RELEASE);
        return scanner;
    }
    scanner->fd = read_fd;
    scanner->pid = child_pid;

    pthread_t *thread = xmalloc(sizeof(pthread_t));
    if (pthread_create(thread, NULL, exec_producer, scanner) != 0) {
        // Couldn't spawn a producer thread; degrade gracefully by producing
        // synchronously on this thread (correct, just not asynchronous).
        free(thread);
        exec_producer(scanner);
    } else {
        scanner->thread = thread;
    }
    return scanner;
}

void scanner_stop(scanner_t *scanner) {
    if (scanner->kind != SCANNER_EXEC) {
        return;
    }
    // Kill the child to unblock the producer if it is mid-read(). Safe even if
    // the child has already exited: we don't reap it until after the join
    // below, so its PID stays valid (never reused) and the signal cannot land
    // on an unrelated process.
    if (scanner->pid > 0) {
        // Negative PID: signal the shell and everything it spawned, so the
        // producer's read() gets EOF promptly and the join below is fast.
        kill(-scanner->pid, SIGKILL);
    }
    if (scanner->thread) {
        pthread_join(*(pthread_t *)scanner->thread, NULL);
        free(scanner->thread);
        scanner->thread = NULL;
    }
    if (scanner->pid > 0) {
        waitpid(scanner->pid, NULL, 0);
        scanner->pid = -1;
    }
    if (scanner->fd >= 0) {
        close(scanner->fd);
        scanner->fd = -1;
    }
    __atomic_store_n(&scanner->done, 1, __ATOMIC_RELEASE);
}

void scanner_wait(scanner_t *scanner) {
    if (scanner->kind != SCANNER_EXEC) {
        return;
    }
    // Unlike stop(), join before signalling the command so all output is read.
    // The producer has already finished inline if pthread_create() failed.
    if (scanner->thread) {
        pthread_join(*(pthread_t *)scanner->thread, NULL);
        free(scanner->thread);
        scanner->thread = NULL;
    }
    // Match the UI's completion cleanup: kill any remaining process-group
    // members, reap the child, and close the pipe. The child is still unreaped,
    // so its PID cannot have been recycled while the producer was finishing.
    scanner_stop(scanner);
}

unsigned commandt_scanner_count_snapshot(const scanner_t *scanner) {
    return scanner_count_snapshot(scanner);
}

bool scanner_done(scanner_t *scanner) {
    if (scanner->kind != SCANNER_EXEC) {
        return true;
    }
    return __atomic_load_n(&scanner->done, __ATOMIC_ACQUIRE) != 0;
}

scanner_t *scanner_new_str(str_t *candidates, unsigned count) {
    scanner_t *scanner = xcalloc(1, sizeof(scanner_t));
    scanner->candidates = candidates;

    // Hint to not `munmap()` memory in `scanner_free();
    scanner->candidates_size = UNOWNED;
    scanner->buffer_size = UNOWNED;

    scanner->count = count;
    scanner->capacity = count;
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
    scanner->capacity = count;
    scanner->candidates = candidates;
    scanner->candidates_size = candidates_size;
    scanner->buffer = buffer;
    scanner->buffer_size = buffer_size;
    return scanner;
}

void scanner_free(scanner_t *scanner) {
    // Join the producer thread and reap the child (a no-op for non-async
    // scanners) before releasing the slabs it may still be writing to.
    scanner_stop(scanner);

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
