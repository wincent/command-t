/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef XMAP_H
#define XMAP_H

#include <stddef.h> /* for size_t */

/**
 * `mmap()` wrapper that calls `abort()` if allocation fails.
 */
void *xmap(size_t size);

#endif
