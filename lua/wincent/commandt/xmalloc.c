// Copyright 2021-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <errno.h> /* for errno */
#include <stdio.h> /* for snprintf() */
#include <stdlib.h> /* for malloc() */

#include "die.h"

#define BUF_SIZE 256

/**
 * `malloc()` wrapper that calls `abort()` if allocation fails.
 */
void *xmalloc(size_t size) {
    void *ptr = malloc(size);
    char err_msg[BUF_SIZE];

    if (!ptr) {
        snprintf(err_msg, BUF_SIZE, "xmallox() failed to malloc %zu bytes", size);

        // Note: A future version of this wrapper might free cached data
        // structures and retry before aborting.
        die(err_msg, errno);
    }

    return ptr;
}
