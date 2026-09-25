/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef SCANNER_H
#define SCANNER_H

#include "commandt.h" /* for scanner_t */
#include "str.h" /* for str_t */

// Define short names for convenience, but all external symbols need prefixes.
#define scanner_new_copy commandt_scanner_new_copy
#define scanner_new_str commandt_scanner_new_str
#define scanner_new commandt_scanner_new
#define scanner_free commandt_scanner_free
#define scanner_new_exec commandt_scanner_new_exec
#define scanner_new_exec_async commandt_scanner_new_exec_async
#define scanner_stop commandt_scanner_stop
#define scanner_wait commandt_scanner_wait
#define scanner_done commandt_scanner_done

/**
 * Snapshot the published candidate count. The acquire pairs with the producer's
 * release stores: candidates below this count are initialized and immutable.
 * Keep the scanner alive while using the snapshot and its candidates.
 * Also valid for eager scanners. Does not wait for production to finish.
 */
static inline unsigned scanner_count_snapshot(const scanner_t *scanner) {
    return __atomic_load_n(&scanner->count, __ATOMIC_ACQUIRE);
}

// Exported wrapper for FFI callers; C callers use the inline helper above.
unsigned commandt_scanner_count_snapshot(const scanner_t *scanner);

/**
 * Create a new `scanner_t` struct initialized with `candidates`.
 *
 * Copies are made of `candidates`. The caller should call `scanner_free()` when
 * done.
 */
scanner_t *scanner_new_copy(const char **candidates, unsigned count);

/**
 * Blocking wrapper around `scanner_new_exec_async()` followed by
 * `scanner_wait()`. All candidates are present on return.
 *
 * The `drop` parameter indicates how many characters of prefix, if any, should
 * be omitted from the strings returned by the scanner; commonly, this will be
 * 0, but for commands such as `find .` which prefix all paths with "./", `drop`
 * would be 2.
 */
scanner_t *scanner_new_exec(const char *command, unsigned drop, unsigned max_files);

/**
 * Run the NUL-terminated shell `command` and produce candidates on a background
 * thread, appending them to the slab and publishing `count` as it goes. The
 * caller polls `scanner_done()` and calls `scanner_stop()` to clean up, or uses
 * `scanner_wait()` to block until production finishes. `scanner_free()` also
 * calls `scanner_stop()`.
 */
scanner_t *scanner_new_exec_async(
    const char *command, unsigned drop, unsigned max_files
);

/**
 * Stop an async scanner: unblock and join its producer thread, reap the child,
 * and close the pipe. A no-op for non-async scanners, and idempotent.
 */
void scanner_stop(scanner_t *scanner);

/**
 * Block until production finishes, then perform the same cleanup as
 * `scanner_stop()`. Unlike stop, does not cancel an in-progress scan. Once
 * stdout closes, any command processes still running are terminated; this
 * waits for scanner completion, not for all of the command's remaining work.
 * Idempotent and a no-op for non-async scanners. Like stop/free, must be called
 * on the owning thread, without concurrent lifecycle operations. Intended for
 * benchmarks, not Neovim's main loop.
 */
void scanner_wait(scanner_t *scanner);

/**
 * Whether an async scanner has finished producing candidates. Always true for
 * non-async scanners.
 */
bool scanner_done(scanner_t *scanner);

/**
 * Create a new `scanner_t` struct initialized with `candidates` provided by
 * the caller.
 *
 * Does not take ownership of the memory (the caller is responsible for keeping
 * the `candidates` memory alive and freeing it).
 */
scanner_t *scanner_new_str(str_t *candidates, unsigned count);

/**
 * Create a `scanner_t` struct initialized with the provide values.
 *
 * This is a low-level counterpart to `scanner_new_str`; like that function,
 * this one does not make copies of the provided values but note that _unlike_
 * `scanner_new_str`, it _does_ take ownership of them.
 */
scanner_t *scanner_new(
    unsigned count,
    str_t *candidates,
    size_t candidates_size,
    char *buffer,
    size_t buffer_size
);

/**
 * Frees a previously created `scanner_t` structure.
 */
void scanner_free(scanner_t *scanner);

#endif
