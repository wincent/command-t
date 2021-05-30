// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#include <ruby.h>

#define UNSET_BITMASK (-1)

// Struct for representing an individual match.
typedef struct {
    VALUE path;
    long bitmask;
    float score;
} match_t;

extern float calculate_match(
    VALUE str,
    VALUE needle,
    VALUE case_sensitive,
    VALUE always_show_dot_files,
    VALUE never_show_dot_files,
    VALUE recurse,
    long needle_bitmask,
    long *haystack_bitmask
);
