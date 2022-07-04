// Copyright 2021-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <errno.h> /* for errno */
#include <stdio.h> /* for snprintf() */
#include <stdlib.h> /* for malloc() */

#include "die.h"

#define BUF_SIZE 256

/**
 * `malloc()` wrapper that calls `abort()` if allocation fails.
 *
 * Note: A future version of this wrapper might free cached data structures and
 * retry before aborting.
 */
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
