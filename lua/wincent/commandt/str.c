/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell. All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "stdlib.h" /* for free() */
#include "string.h" /* for memcpy() */

#include "str.h"
#include "xmalloc.h"

str_t *str_new(const char *source, size_t length) {
    str_t *str = xmalloc(sizeof(str_t));
    str->contents = xmalloc(length);
    str->length = length;
    memcpy(str->contents, source, length);
    return str;
}

void str_free(str_t *str) {
    free(str->contents);
    free(str);
}
