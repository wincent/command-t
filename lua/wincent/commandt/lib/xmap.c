/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <assert.h> /* for assert() */
#include <stddef.h> /* for NULL */
#include <stdlib.h> /* for abort() */
#include <sys/mman.h> /* for mmap(), munmap() */

#include "xmap.h"

void *xmap(size_t size) {
    void *result = mmap(
        NULL,
        size,
        PROT_READ | PROT_WRITE,
        MAP_ANONYMOUS | MAP_NORESERVE | MAP_PRIVATE,
        -1, // "File descriptor" (used as flag).
        0 // Offset into "file" (ignored).
    );
    if (result == MAP_FAILED) {
        abort();
    }
    return result;
}

int xmunmap(void *address, size_t length) {
    int munmapped = munmap(address, length);
    assert(munmapped == 0);
    return munmapped;
}
