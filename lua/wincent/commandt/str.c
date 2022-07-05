/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell. All rights reserved.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include <stdlib.h> /* for free() */
#include <string.h> /* for memcpy() */

#include "str.h"
#include "xmalloc.h"

// When allocating memory, reserve a little more than was asked for,
// which can help to avoid subsequent allocations.
#define STR_OVERALLOC 256

str_t *str_new_copy(const char *source, size_t length) {
    str_t *str = xmalloc(sizeof(str_t));
    str->contents = xmalloc(length);
    str->length = length;
    str->capacity = length;
    memcpy((void *)str->contents, source, length);
    return str;
}

str_t *str_new(void) {
    str_t *str = xmalloc(sizeof(str_t));
    str->contents = xcalloc(STR_OVERALLOC, 1);
    str->length = 0;
    str->capacity = STR_OVERALLOC;
    return str;
}

void str_append(str_t *str, const char *source, size_t length) {
    size_t new_length = str->length + length;
    if (str->capacity < new_length) {
        str->contents = xrealloc((void *)str->contents, new_length + STR_OVERALLOC);
        str->capacity = new_length = STR_OVERALLOC;
    }
    memcpy((void *)str->contents + str->length, source, length);
    str->length = new_length;
}

void str_append_str(str_t *str, str_t *other) {
    str_append(str, other->contents, other->length);
}

void str_free(str_t *str) {
    free((void *)str->contents);
    free(str);
}
