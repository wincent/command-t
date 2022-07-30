/**
 * SPDX-FileCopyrightText: Copyright 2022-present Greg Hurrell and contributors.
 * SPDX-License-Identifier: BSD-2-Clause
 */

#include "str.h"

#include <assert.h> /* for assert() */
#include <stdlib.h> /* for free() */
#include <string.h> /* for memcpy() */

#include "xmalloc.h"

// When allocating memory, reserve a little more than was asked for,
// which can help to avoid subsequent allocations.
#define STR_OVERALLOC 256

// Special `capacity` value to flag a `str_t` as having been "slab" allocated.
#define SLAB_ALLOCATION -1

#define NULL_PADDING 1

str_t *str_new_copy(const char *source, size_t length) {
    assert(length < SSIZE_MAX);
    str_t *str = xmalloc(sizeof(str_t));
    str->contents = xmalloc(length + NULL_PADDING);
    str->length = length;
    str->capacity = length + NULL_PADDING;
    memcpy((void *)str->contents, source, length);
    char *end = (char *)str->contents + length;
    end[0] = '\0';
    return str;
}

str_t *str_new_size(size_t length) {
    assert(length < SSIZE_MAX);
    str_t *str = xmalloc(sizeof(str_t));
    str->contents = xmalloc(length + NULL_PADDING);
    str->length = 0;
    str->capacity = length + NULL_PADDING;
    ((char *)str->contents)[0] = '\0';
    return str;
}

void str_init(str_t *str, const char *source, size_t length) {
    assert(length < SSIZE_MAX);
    str->contents = source;
    str->length = length;
    str->capacity = SLAB_ALLOCATION;
}

void str_init_copy(str_t *str, const char *source, size_t length) {
    assert(length < SSIZE_MAX);
    str->contents = xmalloc(length + NULL_PADDING);
    str->length = length;
    str->capacity = length + NULL_PADDING;
    memcpy((void *)str->contents, source, length);
    char *end = (char *)str->contents + length;
    end[0] = '\0';
}

// Internal only, so doesn't need to be fast/cheap. This is currently only used
// by `scanner_dump()` (a debugging function).
str_t *str_new(void) {
    str_t *str = xmalloc(sizeof(str_t));
    str->contents = xcalloc(STR_OVERALLOC, 1);
    str->length = 0;
    str->capacity = STR_OVERALLOC;
    return str;
}

void str_append(str_t *str, const char *source, size_t length) {
    assert(str->capacity != SLAB_ALLOCATION);
    size_t new_length = str->length + length;
    assert(new_length + NULL_PADDING < SSIZE_MAX);
    if (str->capacity < (ssize_t)(new_length + NULL_PADDING)) {
        str->contents =
            xrealloc((void *)str->contents, new_length + STR_OVERALLOC);
        str->capacity = new_length + STR_OVERALLOC;
    }
    memcpy((void *)str->contents + str->length, source, length + NULL_PADDING);
    str->length = new_length;
}

void str_append_char(str_t *str, char c) {
    assert(str->capacity != SLAB_ALLOCATION);
    size_t new_length = str->length + 1;
    assert(new_length + NULL_PADDING < SSIZE_MAX);
    if (str->capacity < (ssize_t)(new_length + NULL_PADDING)) {
        str->contents =
            xrealloc((void *)str->contents, new_length + STR_OVERALLOC);
        str->capacity = new_length + STR_OVERALLOC;
    }
    ((char *)str->contents)[str->length] = c;
    ((char *)str->contents)[str->length + 1] = '\0';
    str->length = new_length;
}

void str_append_str(str_t *str, str_t *other) {
    str_append(str, other->contents, other->length);
}

void str_truncate(str_t *str, size_t length) {
    assert(str->length > length);
    str->length = length;
    ((char *)str->contents)[length] = '\0';
}

void str_free(str_t *str) {
    // If we were part of a "slab" allocation, do nothing. We should get freed
    // automatically when our slab gets freed.
    if (str->capacity != SLAB_ALLOCATION) {
        free((void *)str->contents);
        free(str);
    }
}

const char *str_c_string(str_t *str) {
    char *c_string = xmalloc(str->length + NULL_PADDING);
    memcpy(c_string, str->contents, str->length);
    (c_string + str->length)[0] = '\0';
    return c_string;
}
