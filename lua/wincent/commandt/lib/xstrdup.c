/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stddef.h> /* for NULL */
#include <stdlib.h> /* for abort() */
#include <string.h> /* for strdup() */

char *xstrdup(const char *str) {
    char *copy = strdup(str);
    if (copy == NULL) {
        abort();
    }
    return copy;
}
