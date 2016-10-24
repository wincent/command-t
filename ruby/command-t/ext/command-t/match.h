// Copyright 2010-present Greg Hurrell. All rights reserved.
// Licensed under the terms of the BSD 2-clause license.

#ifndef MATCH_H
#define MATCH_H

#include <ruby.h>

#define UNSET_BITMASK (-1)

// Struct for representing an individual match.
typedef struct {
    char *path;
    int32_t path_len;
    float score;
    long bitmask;
} match_t;

// Struct for representing a collection of matches.
typedef struct {
    int len;
    match_t matches[];
} matches_t;

extern float calculate_match(
    VALUE needle,
    VALUE case_sensitive,
    VALUE always_show_dot_files,
    VALUE never_show_dot_files,
    VALUE recurse,
    long needle_bitmask,
    match_t *haystack
);

#endif
