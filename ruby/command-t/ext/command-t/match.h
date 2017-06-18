// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#ifndef MATCH_H
#define MATCH_H

#include <ruby.h>

#include "scanner.h"

#define UNSET_BITMASK (-1)

// Struct for representing an individual match.
typedef struct {
    float score;
    paths_t *path;
} match_t;

extern float calculate_match(
    const char *haystack,
    size_t haystack_len,
    VALUE needle,
    VALUE case_sensitive,
    VALUE recurse);

#endif
