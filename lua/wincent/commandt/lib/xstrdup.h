/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#ifndef XSTRDUP_H
#define XSTRDUP_H

/**
 * `strdup()` wrapper that calls `abort()` if allocation fails.
 */
char *xstrdup(const char *str);

#endif
