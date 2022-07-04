/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell. All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdlib.h> /* for free() */
#include <string.h> /* for memcpy() */

#include "str.h"
#include "xmalloc.h"

str_t *str_new(const char *source, size_t length) {
    const char *contents = xmalloc(length);
    memcpy((void *)contents, source, length);
    str_t s = {.contents = contents, .length = length};
    str_t *str = xmalloc(sizeof(str_t));
    memcpy((void *)str, &s, sizeof(str_t));
    return str;
}

void str_free(str_t *str) {
    free((void *)str->contents);
    free(str);
}
