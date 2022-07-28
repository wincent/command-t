/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef XMAP_H
#define XMAP_H

// Define short names for convenience, but all external symbols need prefixes.
#define xmap commandt_xmap
#define xmunmap commandt_xmunmap

#include <stddef.h> /* for size_t */

/**
 * `mmap()` wrapper that calls `abort()` if allocation fails.
 */
void *xmap(size_t size);

/**
 * `munmap()` wrapper that uses `assert()` to confirm success.
 *
 * That is, only in DEBUG builds, it will `abort()` on failure.
 */
int xmunmap(void *address, size_t length);

#endif
