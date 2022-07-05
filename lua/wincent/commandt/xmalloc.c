/**
 * SPDX-FileCopyrightText: Copyright 2021-present Greg Hurrell. All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <errno.h> /* for errno */
#include <stdio.h> /* for snprintf() */
#include <stdlib.h> /* for malloc(), realloc() */

#include "die.h"

#define BUF_SIZE 256

void *xcalloc(size_t count, size_t size) {
    void *ptr = calloc(count, size);
    if (!ptr) {
        char *message = malloc(BUF_SIZE);
        if (
            message &&
            snprintf(message, BUF_SIZE, "xcalloc() failed to malloc %zu bytes", size) >= 0
        ) {
            die(message, errno);
        }
        die("xcalloc() failed", errno);
    }
    return ptr;
}

void *xmalloc(size_t size) {
    void *ptr = malloc(size);
    if (!ptr) {
        char *message = malloc(BUF_SIZE);
        if (
            message &&
            snprintf(message, BUF_SIZE, "xmalloc() failed to malloc %zu bytes", size) >= 0
        ) {
            die(message, errno);
        }
        die("xmalloc() failed", errno);
    }
    return ptr;
}

void *xrealloc(void *ptr, size_t size) {
    void *new_ptr = realloc(ptr, size);
    if (!new_ptr) {
        char *message = malloc(BUF_SIZE);
        if (
            message &&
            snprintf(message, BUF_SIZE, "xrealloc() failed to malloc %zu bytes", size) >= 0
        ) {
            die(message, errno);
        }
        die("xrealloc() failed", errno);
    }
    return new_ptr;
}
